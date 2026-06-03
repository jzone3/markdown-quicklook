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
# Drag-to-install affordance.
ln -s /Applications "$STAGING/Applications"

echo "==> Creating disk image: $OUT_DMG"
rm -f "$OUT_DMG"
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "$STAGING" \
  -ov \
  -fs HFS+ \
  -format UDZO \
  "$OUT_DMG"

rm -rf "$STAGING"
echo "==> Done: $OUT_DMG"
hdiutil verify "$OUT_DMG" >/dev/null && echo "==> Verified disk image OK"
