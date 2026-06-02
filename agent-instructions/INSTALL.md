# Agent Install Instructions

This guide is written for Devin or another coding agent installing Markdown QuickLook on a user's Mac.

## Goal

Build the macOS app, install it to the user's `~/Applications` folder, register the bundled Quick Look extension, enable it, and verify Markdown files preview with the spacebar.

## Requirements

- macOS 12 or later
- Xcode installed
- Homebrew available
- A usable local Apple Development signing certificate, or permission to fall back to Xcode manual signing
- Repo checked out on `master`

## Fast path: build and install from Terminal

Run from the repository root:

```bash
brew list xcodegen >/dev/null 2>&1 || brew install xcodegen
xcodegen generate
```

Discover a local signing team ID:

```bash
TEAM_ID="$(
  security find-certificate -c 'Apple Development' -p \
    | openssl x509 -noout -subject \
    | sed -n 's/.* OU=\([^,]*\).*/\1/p' \
    | head -1
)"

echo "$TEAM_ID"
```

If `TEAM_ID` is empty, stop and ask the user to open the project in Xcode and choose a signing team on both targets.

Build the app and extension:

```bash
xcodebuild \
  -project MarkdownQuickLook.xcodeproj \
  -scheme MarkdownQuickLook \
  -configuration Debug \
  -derivedDataPath .derivedData-signed \
  build \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY='Apple Development' \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  PROVISIONING_PROFILE_SPECIFIER=
```

Install to the user's Applications folder:

```bash
mkdir -p "$HOME/Applications"
ditto .derivedData-signed/Build/Products/Debug/MarkdownQuickLook.app \
  "$HOME/Applications/MarkdownQuickLook.app"
```

Register and enable the Quick Look extension:

```bash
open -gj "$HOME/Applications/MarkdownQuickLook.app"
sleep 2
pluginkit -e use -i com.devin.markdownquicklook.QuickLookExtension || true
qlmanage -r
qlmanage -r cache
pluginkit -m -v | grep -i com.devin.markdownquicklook
```

A successful registration usually prints something like:

```text
+    com.devin.markdownquicklook.QuickLookExtension(...)
```

## Manual fallback

If signing fails:

1. Run `open MarkdownQuickLook.xcodeproj`.
2. Select the `MarkdownQuickLook` target and set a signing Team.
3. Select the `QuickLookExtension` target and set the same signing Team.
4. Build and Run the `MarkdownQuickLook` scheme once.
5. Open System Settings → General → Login Items & Extensions → Quick Look.
6. Enable **Markdown Preview**.

## Test after install

Create or use any Markdown file, then either:

```bash
qlmanage -p Examples/sample.md
```

or open Finder, select a `.md` file, and press spacebar.

If the old preview remains cached, run:

```bash
qlmanage -r
qlmanage -r cache
killall quicklookd 2>/dev/null || true
```

Then close and reopen the Quick Look preview.

## Troubleshooting

### Extension appears twice

This usually means macOS discovered both a DerivedData build and the installed app. Keep the installed app at `~/Applications/MarkdownQuickLook.app`; ignore or remove generated local `.derivedData*` folders if needed. Do not commit generated build outputs.

### Preview says the extension failed

Check recent logs:

```bash
log show --last 5m --style compact \
  --predicate 'process == "QuickLookExtension" OR eventMessage CONTAINS[c] "com.devin.markdownquicklook"' \
  | tail -120
```

The current extension intentionally uses native AppKit rendering instead of `WKWebView`, because WebKit helper processes can fail inside Quick Look extension sandboxes.

### Plain text preview still appears

Make sure **Markdown Preview** is enabled in System Settings → General → Login Items & Extensions → Quick Look, then reset Quick Look caches.

## Verification commands for agents

Run these before claiming success:

```bash
swift test
xcodebuild \
  -project MarkdownQuickLook.xcodeproj \
  -scheme MarkdownQuickLook \
  -configuration Debug \
  -derivedDataPath .derivedData-signed \
  build \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY='Apple Development' \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  PROVISIONING_PROFILE_SPECIFIER=
```
