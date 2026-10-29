// Tidewater one-exe launcher. tool/release/pack_launcher.ps1 appends the app folder to this exe; on the first run
// it is unpacked once to %LOCALAPPDATA%\Tidewater\versions\<version>\, then tidewater.exe starts from there.
// Strictly local: reads only its own file, no network. TIDEWATER_UNPACK_ONLY=1 unpacks and exits (CI smoke test),
// reporting errors as exit code + stderr instead of a message box.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shlobj.h>

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <cwctype>
#include <string>
#include <vector>

static bool g_unpackOnly = false;

[[noreturn]] static void Fail(const wchar_t* step) {
  DWORD err = GetLastError();
  wchar_t msg[512];
  swprintf_s(msg, L"Tidewater could not start.\n\nStep: %s\nError: %lu", step, err);
  if (g_unpackOnly) {
    fwprintf(stderr, L"%s\n", msg);
  } else {
    MessageBoxW(nullptr, msg, L"Tidewater", MB_ICONERROR);
  }
  ExitProcess(1);
}

static bool Exists(const std::wstring& path) { return GetFileAttributesW(path.c_str()) != INVALID_FILE_ATTRIBUTES; }

// Deletes a folder tree. Best effort: files in use stay. Junctions are removed, never followed.
static void DeleteTree(const std::wstring& dir) {
  WIN32_FIND_DATAW fd;
  HANDLE find = FindFirstFileW((dir + L"\\*").c_str(), &fd);
  if (find != INVALID_HANDLE_VALUE) {
    do {
      if (!wcscmp(fd.cFileName, L".") || !wcscmp(fd.cFileName, L"..")) continue;
      std::wstring path = dir + L"\\" + fd.cFileName;
      if ((fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) && !(fd.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT)) {
        DeleteTree(path);
      } else if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
        RemoveDirectoryW(path.c_str());
      } else {
        SetFileAttributesW(path.c_str(), FILE_ATTRIBUTE_NORMAL);
        DeleteFileW(path.c_str());
      }
    } while (FindNextFileW(find, &fd));
    FindClose(find);
  }
  RemoveDirectoryW(dir.c_str());
}

static void MakeDirs(const std::wstring& dir) {
  int rc = SHCreateDirectoryExW(nullptr, dir.c_str(), nullptr);
  if (rc != ERROR_SUCCESS && rc != ERROR_ALREADY_EXISTS && rc != ERROR_FILE_EXISTS) {
    SetLastError(rc);
    Fail(L"create folder");
  }
}

struct Reader {
  HANDLE file;

  void Read(void* buf, DWORD n) {
    DWORD got = 0;
    if (!ReadFile(file, buf, n, &got, nullptr) || got != n) Fail(L"read app payload");
  }
  uint32_t U32() { uint32_t v; Read(&v, sizeof v); return v; }
  uint64_t U64() { uint64_t v; Read(&v, sizeof v); return v; }
  std::wstring Str() {
    uint32_t n = U32();
    if (n == 0 || n > 4096) { SetLastError(ERROR_INVALID_DATA); Fail(L"read app payload"); }
    std::string s(n, '\0');
    Read(&s[0], n);
    int len = MultiByteToWideChar(CP_UTF8, 0, s.data(), (int)n, nullptr, 0);
    std::wstring w(len, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, s.data(), (int)n, &w[0], len);
    return w;
  }
  void Seek(uint64_t pos) {
    LARGE_INTEGER li;
    li.QuadPart = (LONGLONG)pos;
    if (!SetFilePointerEx(file, li, nullptr, FILE_BEGIN)) Fail(L"read app payload");
  }
};

// The payload is ours, but never let a path escape the target folder.
static bool SafeRelative(std::wstring& path) {
  for (auto& c : path) if (c == L'/') c = L'\\';
  return path[0] != L'\\' && path.find(L':') == std::wstring::npos && path.find(L"..") == std::wstring::npos;
}

static void Unpack(Reader& r, const std::wstring& tmp) {
  DeleteTree(tmp);
  MakeDirs(tmp);
  std::vector<char> buf(1 << 20);
  uint32_t count = r.U32();
  for (uint32_t i = 0; i < count; i++) {
    std::wstring rel = r.Str();
    uint64_t size = r.U64();
    if (!SafeRelative(rel)) { SetLastError(ERROR_INVALID_DATA); Fail(L"read app payload"); }
    std::wstring path = tmp + L"\\" + rel;
    MakeDirs(path.substr(0, path.rfind(L'\\')));
    HANDLE out = CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (out == INVALID_HANDLE_VALUE) Fail(L"write app file");
    while (size) {
      DWORD n = (DWORD)(size < buf.size() ? size : buf.size());
      r.Read(buf.data(), n);
      DWORD wrote = 0;
      if (!WriteFile(out, buf.data(), n, &wrote, nullptr) || wrote != n) Fail(L"write app file");
      size -= n;
    }
    CloseHandle(out);
  }
  HANDLE done = CreateFileW((tmp + L"\\.complete").c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, 0, nullptr);
  if (done == INVALID_HANDLE_VALUE) Fail(L"write app file");
  CloseHandle(done);
}

// Removes other versions. .complete goes first, so a folder that is only half deleted (its app still running)
// is unpacked again instead of started broken.
static void CleanOld(const std::wstring& versions, const std::wstring& keep) {
  WIN32_FIND_DATAW fd;
  HANDLE find = FindFirstFileW((versions + L"\\*").c_str(), &fd);
  if (find == INVALID_HANDLE_VALUE) return;
  do {
    std::wstring name = fd.cFileName;
    if (!(fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) || name == L"." || name == L".." || name == keep) continue;
    if (name.find(L".tmp-") != std::wstring::npos) continue;  // another launcher may be unpacking it
    DeleteFileW((versions + L"\\" + name + L"\\.complete").c_str());
    DeleteTree(versions + L"\\" + name);
  } while (FindNextFileW(find, &fd));
  FindClose(find);
}

// The launcher's own arguments, without its exe path.
static const wchar_t* Args() {
  const wchar_t* p = GetCommandLineW();
  if (*p == L'"') {
    for (p++; *p && *p != L'"'; p++) {}
    if (*p) p++;
  } else {
    while (*p && *p != L' ' && *p != L'\t') p++;
  }
  while (*p == L' ' || *p == L'\t') p++;
  return p;
}

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
  wchar_t flag[4] = {};
  g_unpackOnly = GetEnvironmentVariableW(L"TIDEWATER_UNPACK_ONLY", flag, 4) > 0 && flag[0] == L'1';

  wchar_t self[32768];
  DWORD n = GetModuleFileNameW(nullptr, self, 32768);
  if (n == 0 || n == 32768) Fail(L"find launcher");
  HANDLE file = CreateFileW(self, GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN, nullptr);
  if (file == INVALID_HANDLE_VALUE) Fail(L"open launcher");
  Reader r{file};

  LARGE_INTEGER size;
  if (!GetFileSizeEx(file, &size) || size.QuadPart < 16) { SetLastError(ERROR_INVALID_DATA); Fail(L"find app payload"); }
  r.Seek((uint64_t)size.QuadPart - 16);
  uint64_t offset = r.U64();
  char magic[8];
  r.Read(magic, 8);
  if (memcmp(magic, "TWPACK01", 8) || offset >= (uint64_t)size.QuadPart) { SetLastError(ERROR_INVALID_DATA); Fail(L"find app payload"); }
  r.Seek(offset);
  std::wstring version = r.Str();
  for (wchar_t c : version) {
    if (!iswalnum(c) && c != L'.' && c != L'-' && c != L'+' && c != L'_') { SetLastError(ERROR_INVALID_DATA); Fail(L"read app payload"); }
  }

  wchar_t local[MAX_PATH];
  DWORD len = GetEnvironmentVariableW(L"LOCALAPPDATA", local, MAX_PATH);
  if (len == 0 || len >= MAX_PATH) Fail(L"find LocalAppData");
  std::wstring versions = std::wstring(local) + L"\\Tidewater\\versions";
  std::wstring dir = versions + L"\\" + version;

  if (!Exists(dir + L"\\.complete")) {
    std::wstring tmp = dir + L".tmp-" + std::to_wstring(GetCurrentProcessId());
    Unpack(r, tmp);
    if (Exists(dir + L"\\.complete")) {
      DeleteTree(tmp);  // another launcher finished first
    } else {
      if (Exists(dir)) DeleteTree(dir);  // a half-deleted old copy
      if (!MoveFileExW(tmp.c_str(), dir.c_str(), 0)) {
        if (!Exists(dir + L"\\.complete")) Fail(L"move app into place");
        DeleteTree(tmp);
      }
    }
  }
  CloseHandle(file);
  CleanOld(versions, version);
  if (g_unpackOnly) return 0;

  std::wstring exe = dir + L"\\tidewater.exe";
  std::wstring cmd = L"\"" + exe + L"\" " + Args();
  std::vector<wchar_t> cmdBuf(cmd.begin(), cmd.end());
  cmdBuf.push_back(L'\0');
  STARTUPINFOW si = {};
  si.cb = sizeof si;
  PROCESS_INFORMATION pi = {};
  if (!CreateProcessW(exe.c_str(), cmdBuf.data(), nullptr, nullptr, FALSE, 0, nullptr, dir.c_str(), &si, &pi)) {
    Fail(L"start tidewater.exe");
  }
  CloseHandle(pi.hThread);
  CloseHandle(pi.hProcess);
  return 0;
}
