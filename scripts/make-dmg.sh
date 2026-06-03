#!/usr/bin/env bash
#
# Build Markdown QuickLook (Release) and package it into a drag-to-Applications
# .dmg that users can double-click to install.
#
# This must run on macOS with Xcode + Homebrew available. It is used both
# locally and by .github/workflows/release.yml.
#
# Usage:
#   scripts/make-dmg.sh [output.dmg]
#
# Environment overrides:
#   CONFIGURATION   Debug | Release        (default: Release)
#   DEVELOPMENT_TEAM  Apple Team ID         (default: empty -> ad-hoc sign)
#   CODE_SIGN_IDENTITY  e.g. "Developer ID Application: ..." (default: "-")
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

APP_NAME="MarkdownQuickLook"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED="$REPO_ROOT/.derivedData-dmg"
OUT_DMG="${1:-$REPO_ROOT/${APP_NAME}.dmg}"
STAGING="$REPO_ROOT/.dmg-staging"

echo "==> Generating Xcode project"
command -v xcodegen >/dev/null 2>&1 || brew install xcodegen
xcodegen generate

# Code signing: default to ad-hoc ("-") which lets the app run after the user
# clears quarantine. If an Apple Developer team/identity is provided, use it so
# the build can later be notarized for frictionless double-click installs.
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
TEAM="${DEVELOPMENT_TEAM:-}"

echo "==> Building ${APP_NAME} (${CONFIGURATION}); signing identity: ${SIGN_IDENTITY:-ad-hoc}"
xcodebuild \
  -project "${APP_NAME}.xcodeproj" \
  -scheme "${APP_NAME}" \
  -configuration "${CONFIGURATION}" \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="${SIGN_IDENTITY}" \
  DEVELOPMENT_TEAM="${TEAM}" \
  PROVISIONING_PROFILE_SPECIFIER= \
  build

APP_PATH="$DERIVED/Build/Products/${CONFIGURATION}/${APP_NAME}.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "error: built app not found at $APP_PATH" >&2
  exit 1
fi
echo "==> Built app: $APP_PATH"

echo "==> Staging .dmg contents"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"

rm -f "$OUT_DMG"

# A nice disk image shows a background with an arrow from the app to the
# /Applications folder, with both icons positioned. We use `create-dmg` for
# that. If anything in the styled path fails (e.g. AppleScript/Finder is
# unavailable on a headless runner), fall back to a plain drag-to-install image
# so a release is never blocked.
ASSETS="$REPO_ROOT/scripts/dmg-assets"
BG_1X="$ASSETS/dmg-background.png"
BG_2X="$ASSETS/dmg-background@2x.png"

make_plain_dmg() {
  echo "==> Creating plain disk image (fallback): $OUT_DMG"
  rm -f "$OUT_DMG"
  ln -sf /Applications "$STAGING/Applications"
  hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "$STAGING" \
    -ov \
    -fs HFS+ \
    -format UDZO \
    "$OUT_DMG"
  rm -f "$STAGING/Applications"
}

make_styled_dmg() {
  command -v create-dmg >/dev/null 2>&1 || brew install create-dmg

  # Build a HiDPI background so the art is crisp on Retina displays.
  local BG="$ASSETS/dmg-background.tiff"
  if [[ -f "$BG_1X" && -f "$BG_2X" ]] && command -v tiffutil >/dev/null 2>&1; then
    tiffutil -cathidpicheck "$BG_1X" "$BG_2X" -out "$BG" >/dev/null 2>&1 || BG="$BG_1X"
  else
    BG="$BG_1X"
  fi

  echo "==> Creating styled disk image: $OUT_DMG"
  # create-dmg adds the /Applications drop link itself, so the staging folder
  # must contain only the .app.
  create-dmg \
    --volname "${APP_NAME}" \
    --background "$BG" \
    --window-pos 200 120 \
    --window-size 660 400 \
    --icon-size 120 \
    --icon "${APP_NAME}.app" 165 235 \
    --hide-extension "${APP_NAME}.app" \
    --app-drop-link 495 235 \
    --no-internet-enable \
    "$OUT_DMG" \
    "$STAGING"
}

# create-dmg can exit non-zero even when it produced a valid image (e.g. it
# couldn't unmount cleanly), so treat "file exists and verifies" as success.
if make_styled_dmg && [[ -f "$OUT_DMG" ]]; then
  echo "==> Styled disk image created"
elif [[ -f "$OUT_DMG" ]] && hdiutil verify "$OUT_DMG" >/dev/null 2>&1; then
  echo "==> Styled disk image created (create-dmg returned non-zero but image is valid)"
else
  echo "==> Styled packaging failed; falling back to plain image" >&2
  make_plain_dmg
fi

rm -rf "$STAGING"
echo "==> Done: $OUT_DMG"
hdiutil verify "$OUT_DMG" >/dev/null && echo "==> Verified disk image OK"
