# Facade

Native macOS menu-bar editor for `/etc/hosts`. Personal use, Apple Silicon.

## First-time setup

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen):
   ```sh
   brew install xcodegen
   ```
2. Generate the Xcode project:
   ```sh
   xcodegen generate
   ```
3. Open `Facade.xcodeproj` in Xcode and press ⌘B (Release build). The post-build phase copies the app into `/Applications/Facade.app`.
4. Launch `Facade` from Spotlight. Ad-hoc signed, so if Gatekeeper complains on first launch: right-click → Open to bypass.
5. **(Optional, recommended)** Install the passwordless helper so saves don't prompt:
   ```sh
   ./scripts/install-privileged.sh
   ```
   You'll type your password once. After that, every save is instant.

The `.xcodeproj` and `Info.plist` are generated from `project.yml` — they're git-ignored. Re-run `xcodegen generate` if you change `project.yml` or add source files.

## How it works

- SwiftUI `MenuBarExtra` app (`LSUIElement=true`, no Dock icon).
- Reads `/etc/hosts` directly (world-readable).
- Saves via one of two paths, depending on what's installed:
  1. **Helper mode** (after running `install-privileged.sh`): app pipes the
     new contents to `sudo -n /usr/local/bin/facade-save`, which writes the
     file atomically and flushes DNS. No password prompt.
  2. **Fallback mode** (helper not installed): app writes to a temp file
     and runs `osascript ... with administrator privileges` to `cp` it into
     place. Shows the standard admin password prompt; macOS caches the
     authorization for ~5 minutes so bursts of saves are silent.
- DNS flush uses `killall mDNSResponder` (SIGTERM → launchd respawns it with
  a clean cache), *not* `killall -HUP`. HUP only tells mDNSResponder to
  reload config; existing cached DNS answers still win over a newly-added
  `/etc/hosts` entry. A full restart flushes them.
- On launch the app terminates any older Facade instances so you only ever
  have one menu-bar icon. Xcode launches from DerivedData bypass
  LaunchServices' normal single-instancing, so we enforce it manually.

## Passwordless setup — what it does and the tradeoff

`scripts/install-privileged.sh`:

1. Installs `scripts/facade-save` to `/usr/local/bin/facade-save`, owned by
   `root:wheel` with mode 755 (so only root can modify it).
2. Drops a sudoers fragment at `/etc/sudoers.d/facade` granting *only* the
   current user `NOPASSWD` for *only* `/usr/local/bin/facade-save`.

That single command is the only thing that runs without a password — it
doesn't grant shell access or arbitrary root. The helper also refuses to
write an empty file as a sanity check.

Tradeoff: any process running as your user can now write `/etc/hosts` and
flush DNS without prompting. For a personal dev machine this is a
reasonable tradeoff. On a shared or managed-by-IT machine, skip the
installer and live with the fallback prompt.

### Uninstalling the helper

```sh
sudo rm /usr/local/bin/facade-save /etc/sudoers.d/facade
```

Facade automatically falls back to the osascript prompt once the helper is
gone.

## Updating after code changes

- Source changes → ⌘B in Xcode → post-build phase re-installs to `/Applications`.
- Helper script changes → `sudo install -o root -g wheel -m 755 scripts/facade-save /usr/local/bin/facade-save`.
- `project.yml` changes → `xcodegen generate`, then ⌘B.

## Layout

```
project.yml                     # XcodeGen config — source of truth
Facade/
  FacadeApp.swift               # @main, MenuBarExtra scene, single-instance enforcement
  HostsEditorView.swift         # editor UI, save/revert/quit
  HostsFile.swift               # read, helper-or-osascript privileged write
scripts/
  facade-save                   # root helper: stdin → /etc/hosts + DNS flush
  install-privileged.sh         # one-time sudoers + helper installer
```
