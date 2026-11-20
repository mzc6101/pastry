# Pastry

A lightweight clipboard-history manager for macOS 14+ with a Liquid Glass shelf and on-device smart suggestions. Plain `swiftc`, no Xcode project.

## Install (DMG)
1. Download `Pastry.dmg` from the [latest release](../../releases/latest), open it and drag **Pastry** to **Applications**.
2. Pastry isn't notarized by Apple, so the first launch is blocked. Right-click Pastry in Applications → **Open** → **Open**, or run `xattr -dr com.apple.quarantine /Applications/Pastry.app`.
3. Grant Accessibility when asked (System Settings → Privacy & Security → Accessibility) so Pastry can paste for you. Press ⇧⌘V.

## Build and install
    ./build.sh               # builds build/Pastry.app, ad-hoc signs it, quits any running Pastry, installs /Applications/Pastry.app
    ./build.sh --no-install  # build only
    open -a Pastry

The build also draws the app icon (`tools/make-icon.swift` -> iconset -> `iconutil`).

## Use
- Cmd-Shift-V (changeable) opens the shelf. Return pastes, Shift-Return pastes plain/rich (inverse of your default), Cmd-1..9 paste a card, Cmd-P pins, Tab toggles Pinned, Backspace deletes the selected card, Esc closes. Right-click a card for Paste / Paste as Plain Text / Copy / Edit Text… / Pin / Open / Reveal in Finder / Quick Look / Share… / Delete.
- Smart suggestions: the right-most three tiles ("Suggested for <App>") are picked from your history for the app you are in, by a fast rule-based ranker that the on-device Apple Intelligence model refines when available (cached per app and history, nothing leaves the Mac). Shift-Right jumps to the first tile, Shift-Left returns to history; Cmd-Right also turns suggestions on if they are off; the sparkles button next to the gear (or Settings > General) turns it off. Clicking elsewhere or switching apps closes it.
- There is no menu bar item. Settings: gear button on the shelf, Cmd-, , or open Pastry again. Quit: Cmd-Q or Settings > General > Quit.
- Pasting into other apps needs Accessibility: System Settings > Privacy & Security > Accessibility > add /Applications/Pastry.app. The shelf shows a banner with a button until granted. `build.sh` signs with a self-signed "Pastry Dev" code-signing identity (login keychain) so the grant survives rebuilds; if it is missing it falls back to ad-hoc with a fixed designated requirement. The shelf and Settings poll the trust state live and offer "Relaunch Pastry" when a grant exists but this process predates it.
- Data: `~/Library/Application Support/Pastry/history.sqlite`; preferences in UserDefaults `com.manavchordia.pastry`.

## Debug
`PASTRY_DB=<path>` scratch database, `PASTRY_AUTOSHOW=1` show the shelf at launch, `PASTRY_APPEARANCE=dark|light` force appearance, `PASTRY_NO_GLASS=1` use the pre-macOS-26 material look, `PASTRY_AX_FORCE=missing|stale|trusted` fake the Accessibility banner state, `PASTRY_AUTOSETTINGS=<tab>` open Settings at launch, `PASTRY_AUTOMENU=menu|edit|editsave` open a card menu/editor at launch, `PASTRY_NO_AX_PROMPT=1` skip the one-time Accessibility prompt, `Pastry --dump` list stored items. With `open`, pass `--env VAR=x --stdout file` to see the log.

## Signing
Create the identity once: `openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj /CN=Pastry\ Dev -addext keyUsage=critical,digitalSignature -addext extendedKeyUsage=critical,codeSigning -keyout k.pem -out c.pem`, then `openssl pkcs12 -export -inkey k.pem -in c.pem -out p.p12 -passout pass:x` and `security import p.p12 -k ~/Library/Keychains/login.keychain-db -P x -T /usr/bin/codesign`.

## Launch video
`launch-video/` is a Remotion project (`npm install`, then `npx remotion render src/index.ts Pastry out/pastry-launch.mp4`). App icons are not checked in: export them from `/System/Applications/*.app` into `launch-video/public/apps/` (finder, mail, messages, notes, photos, preview, safari, terminal `.png`) before rendering.
