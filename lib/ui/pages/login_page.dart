import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/session_providers.dart';
import '../../app/theme/motion.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/connect.dart';
import '../../core/api/server_config.dart';
import '../shell/title_bar.dart';
import '../widgets/effects/letter_reveal.dart';
import '../widgets/effects/ripple.dart';
import '../widgets/animated_glyphs.dart';
import '../widgets/expressive_buttons.dart';
import '../widgets/pressable.dart';
import 'widgets/login_scene.dart';

/// Server URL, user and password / API key. Shown whenever no server is
/// saved. Errors are specific (bad address, unreachable, certificate, wrong
/// credentials) and a rejected certificate can be trusted for this server.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  late final TextEditingController _url;
  late final TextEditingController _user;
  final _secret = TextEditingController();
  final _userFocus = FocusNode();
  final _secretFocus = FocusNode();

  bool _useKey = false;
  bool _busy = false;
  bool _showSecret = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    final last = ref.read(sessionStoreProvider).lastServer;
    _url = TextEditingController(text: last.url);
    _user = TextEditingController(text: last.user);
  }

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _secret.dispose();
    _userFocus.dispose();
    _secretFocus.dispose();
    super.dispose();
  }

  Future<void> _submit({bool trustCertificate = false}) async {
    if (_busy) return;
    final secret = _secret.text;
    if (_url.text.trim().isEmpty ||
        secret.isEmpty ||
        (!_useKey && _user.text.trim().isEmpty)) {
      setState(
        () => _error = ApiException(
          ApiErrorKind.badUrl,
          _url.text.trim().isEmpty
              ? 'Enter your server address.'
              : (_useKey
                    ? 'Enter your API key.'
                    : 'Enter your username and password.'),
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final user = _user.text.trim();
    try {
      final connection = await connect(
        url: _url.text,
        credentials: _useKey
            ? ApiKeyCredentials(secret, username: user)
            : PasswordCredentials(user, secret),
        trustBadCertificate: trustCertificate,
        factory: ref.read(clientFactoryProvider),
      );
      await ref.read(sessionProvider.notifier).signIn(connection.config);
      // The router now replaces this page.
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = ApiException(
            ApiErrorKind.server,
            'Something went wrong: $e',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final error = _error;
    return Material(
      color: scheme.surface,
      child: LayoutBuilder(
        builder: (context, box) {
          // Wide windows put the form on the left and the sun on the right.
          final wide = box.maxWidth >= 900;
          return Stack(
            children: [
              Positioned.fill(
                child: LoginScene(
                  sunX: wide ? .7 : .5,
                  horizon: wide ? .66 : .74,
                ),
              ),
              Align(
                alignment: wide ? const Alignment(-.5, 0) : Alignment.center,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 56, 24, 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainer.withValues(alpha: .86),
                        borderRadius: BorderRadius.circular(36),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(32, 36, 32, 28),
                        child: AutofillGroup(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Semantics(
                                header: true,
                                child: Center(
                                  child: LetterReveal(
                                    text: 'Tidewater',
                                    style: text.displaySmall,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Connect to your Navidrome server',
                                textAlign: TextAlign.center,
                                style: text.bodyLarge?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 32),
                              _Field(
                                controller: _url,
                                label: 'Server address',
                                hint: 'music.example.com or http://192.168.1.5:4533',
                                icon: Icons.dns_rounded,
                                autofocus: _url.text.isEmpty,
                                keyboard: TextInputType.url,
                                onSubmitted: (_) =>
                                    (_useKey ? _secretFocus : _userFocus)
                                        .requestFocus(),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: ExpressiveChipGroup(
                                  labels: const ['Password', 'API key'],
                                  selectedIndex: _useKey ? 1 : 0,
                                  onSelected: (i) => setState(() {
                                    _useKey = i == 1;
                                    _secret.clear();
                                    _error = null;
                                  }),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (!_useKey) ...[
                                _Field(
                                  controller: _user,
                                  focusNode: _userFocus,
                                  label: 'Username',
                                  icon: Icons.person_rounded,
                                  autofocus:
                                      _url.text.isNotEmpty &&
                                      _user.text.isEmpty,
                                  autofill: const [AutofillHints.username],
                                  onSubmitted: (_) =>
                                      _secretFocus.requestFocus(),
                                ),
                                const SizedBox(height: 12),
                              ],
                              _Field(
                                controller: _secret,
                                focusNode: _secretFocus,
                                label: _useKey ? 'API key' : 'Password',
                                icon: Icons.key_rounded,
                                autofocus:
                                    _url.text.isNotEmpty &&
                                    _user.text.isNotEmpty,
                                obscure: !_showSecret,
                                autofill: _useKey
                                    ? null
                                    : const [AutofillHints.password],
                                trailing: ExpressiveIconButton(
                                  icon: _showSecret
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  glyph: (context, color, hovered, pressed) =>
                                      AnimatedGlyph(
                                        kind: _showSecret
                                            ? GlyphKind.eyeOff
                                            : GlyphKind.eye,
                                        size: 22,
                                        color: color,
                                        active: pressed,
                                      ),
                                  tooltip: _showSecret ? 'Hide' : 'Show',
                                  tone: ButtonTone.ghost,
                                  size: 40,
                                  iconSize: 20,
                                  onPressed: () => setState(
                                    () => _showSecret = !_showSecret,
                                  ),
                                ),
                                onSubmitted: (_) => _submit(),
                              ),
                              AnimatedSize(
                                duration: Motion.of(context, Motion.medium),
                                curve: Motion.curve(context, Motion.emphasized),
                                alignment: Alignment.topCenter,
                                child: error == null
                                    ? const SizedBox(width: double.infinity)
                                    : Padding(
                                        padding: const EdgeInsets.only(top: 16),
                                        child: _ErrorBox(
                                          error: error,
                                          onTrust:
                                              error.kind == ApiErrorKind.tls
                                              ? () => _submit(
                                                  trustCertificate: true,
                                                )
                                              : null,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 24),
                              _ConnectButton(busy: _busy, onTap: _submit),
                              const SizedBox(height: 16),
                              Text(
                                'Your password or key is stored in Windows\' secure credential storage on this PC.',
                                textAlign: TextAlign.center,
                                style: text.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned(left: 0, right: 0, top: 0, child: TitleBar()),
            ],
          );
        },
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.focusNode,
    this.hint,
    this.obscure = false,
    this.autofocus = false,
    this.keyboard,
    this.autofill,
    this.trailing,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String? hint;
  final IconData icon;
  final bool obscure;
  final bool autofocus;
  final TextInputType? keyboard;
  final Iterable<String>? autofill;
  final Widget? trailing;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    OutlineInputBorder border(Color c, [double w = 0]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: w == 0 ? BorderSide.none : BorderSide(color: c, width: w),
    );
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      obscureText: obscure,
      keyboardType: keyboard,
      autofillHints: autofill,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.next,
      onSubmitted: onSubmitted,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: .6),
        ),
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        prefixIcon: Icon(icon, color: scheme.onSurfaceVariant),
        suffixIcon: trailing == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(right: 8),
                child: trailing,
              ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 18,
        ),
        border: border(scheme.surfaceContainerHigh),
        enabledBorder: border(scheme.surfaceContainerHigh),
        focusedBorder: border(scheme.primary, 2),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.error, this.onTrust});

  final ApiException error;
  final VoidCallback? onTrust;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 20,
                  color: scheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    error.message,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onErrorContainer),
                  ),
                ),
              ],
            ),
            if (onTrust != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Pressable(
                  onTap: onTrust!,
                  semanticLabel: 'Trust this server and connect',
                  builder: (context, s) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: s.hovered
                          ? scheme.onErrorContainer.withValues(alpha: .16)
                          : scheme.onErrorContainer.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Trust this server',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConnectButton extends StatelessWidget {
  const _ConnectButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      onTap: onTap,
      semanticLabel: busy ? 'Connecting' : 'Connect',
      builder: (context, s) => AnimatedScale(
        scale: s.pressed ? .97 : 1,
        duration: Motion.of(context, Motion.fast),
        curve: Motion.curve(context, Motion.spring),
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.slow),
          curve: Motion.curve(context, Motion.spring),
          height: 56,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(busy || s.pressed ? 16 : 28),
          ),
          child: Ripple(
            color: scheme.onPrimary,
            child: Center(
              child: busy
                  ? SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: scheme.onPrimary,
                      ),
                    )
                  : Text(
                      'Connect',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onPrimary,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
