# Facade

A native macOS menu-bar editor for `/etc/hosts`.

SwiftUI `MenuBarExtra` app for Apple Silicon. No Dock icon, no Electron, no background daemon — just a small window that reads and writes the hosts file and flushes DNS when you save.

## Install

```sh
brew install xcodegen
xcodegen generate
open Facade.xcodeproj
```

Press ⌘B in Xcode. The post-build phase copies the app into `/Applications`. The build is ad-hoc signed, so on first launch right-click → Open to get past Gatekeeper.

The `.xcodeproj` and `Info.plist` are generated from `project.yml` and git-ignored. Re-run `xcodegen generate` after changing `project.yml` or adding sources.

## Saving

Writing `/etc/hosts` requires root. Facade supports two paths:

- **Default (fallback):** uses `osascript` with administrator privileges, which shows the standard macOS password prompt. The authorization is cached for ~5 minutes, so bursts of saves are silent.
- **Passwordless (optional):**
  ```sh
  ./scripts/install-privileged.sh
  ```
  Installs a small root-owned helper at `/usr/local/bin/facade-save` and a sudoers fragment granting your user `NOPASSWD` for *only* that helper. After the one-time password prompt, saves are instant.

The helper refuses to write an empty file. Any process running as your user can invoke it without a prompt — reasonable for a personal machine, less so for a shared or managed one. Skip the installer if that's a concern.

### Uninstall the helper

```sh
sudo rm /usr/local/bin/facade-save /etc/sudoers.d/facade
```

Facade falls back to the password prompt automatically.

## DNS flush

Saves run `killall mDNSResponder` (SIGTERM, launchd respawns it). `killall -HUP` only reloads config — already-cached answers still beat new `/etc/hosts` entries. A full restart clears them.

## License

GPL-3.0.
