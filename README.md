# Switcheroo

A native macOS menu-bar editor for `/etc/hosts`. Built for quickly switching the file's contents — toggling between dev/staging/prod overrides, flipping a domain to localhost and back, etc.

A modern replacement for [Gas Mask](https://github.com/2ndalpha/gasmask), which is largely abandoned and unreliable on recent Apple Silicon macOS. Switcheroo also flushes DNS automatically on every save, so changes take effect immediately without a separate `dscacheutil` dance.

SwiftUI `MenuBarExtra` app for Apple Silicon. No Dock icon, no Electron, no background daemon.

## Install

```sh
brew install xcodegen
xcodegen generate
open Switcheroo.xcodeproj
```

Press ⌘B in Xcode. The post-build phase copies the app into `/Applications`. The build is ad-hoc signed, so on first launch right-click → Open to get past Gatekeeper.

The `.xcodeproj` and `Info.plist` are generated from `project.yml` and git-ignored. Re-run `xcodegen generate` after changing `project.yml` or adding sources.

## Saving

Writing `/etc/hosts` requires root. Switcheroo supports two paths:

- **Default (fallback):** uses `osascript` with administrator privileges, which shows the standard macOS password prompt. The authorization is cached for ~5 minutes, so bursts of saves are silent.
- **Passwordless (optional):**
  ```sh
  ./scripts/install-privileged.sh
  ```
  Installs a small root-owned helper at `/usr/local/bin/switcheroo-save` and a sudoers fragment granting your user `NOPASSWD` for *only* that helper. After the one-time password prompt, saves are instant.

The helper refuses to write an empty file. Any process running as your user can invoke it without a prompt — reasonable for a personal machine, less so for a shared or managed one. Skip the installer if that's a concern.

### Uninstall the helper

```sh
sudo rm /usr/local/bin/switcheroo-save /etc/sudoers.d/switcheroo
```

Switcheroo falls back to the password prompt automatically.

## DNS flush

Saves run `killall mDNSResponder` (SIGTERM, launchd respawns it). `killall -HUP` only reloads config — already-cached answers still beat new `/etc/hosts` entries. A full restart clears them.

### Post-save command

The gear icon opens a settings popover with one field: a shell command to run after every successful save (via `/bin/sh -c`). Useful when something downstream of `/etc/hosts` needs a kick — a proxy app holding stale sockets, a long-running service caching resolutions, etc.

Example: if you're behind an SSH-tunnel proxy app that doesn't pick up `/etc/hosts` changes until it reconnects, quit-and-relaunch it on every save. Replace `MyProxyApp` with the actual app name:

```sh
osascript -e 'tell application "MyProxyApp" to quit'; for i in $(seq 1 50); do pgrep -x MyProxyApp >/dev/null 2>&1 || break; sleep 0.1; done; open -a MyProxyApp
```

The loop polls every 100ms for up to 5s so the relaunch waits for the old process to actually exit (otherwise `open` just activates the still-quitting instance and the app ends up not running).

### When the flush won't help

`/etc/hosts` only matters if your machine is the one doing DNS resolution. Some things bypass it entirely:

- **System-wide HTTP/SOCKS proxies** (e.g. AutoProxy, Charles, corporate PAC files) — the proxy server resolves the hostname, not your laptop.
- **Browser connection reuse** — an already-open keep-alive socket to the old IP will be reused even after a flush. Quit/relaunch the browser, or clear sockets (Chrome: `chrome://net-internals/#sockets`).
- **Apps with their own DNS caches** — some long-running apps cache resolutions in-process.

## License

GPL-3.0.
