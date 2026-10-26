# Security policy

## Reporting a vulnerability

Please **don't open a public issue** for a security problem. Use GitHub's private reporting instead:

1. Go to the repository's **Security** tab.
2. Choose **Report a vulnerability**.
3. Describe what you found and how to reproduce it.

You'll get a reply in the same private thread. Please give me a reasonable amount of time to fix it before
sharing details publicly.

## What counts

Tidewater signs in to a Navidrome / OpenSubsonic server, so the things I care most about are:

- credentials (password or API key) leaking: into logs, files, URLs or the network
- the app sending your library or listening data somewhere you didn't choose
- a malicious server or file crashing the app or running code
- problems in a dependency that affect the app (Dependabot alerts are on, but a heads-up is welcome)

## Supported versions

Only the latest code on `main` gets fixes. There are no long-term release branches.

## Please don't include secrets

When you report a bug or a vulnerability, remove passwords, API keys, tokens and server addresses you want to
keep private from logs and screenshots before attaching them.
