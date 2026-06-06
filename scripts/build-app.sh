#!/bin/bash
# Swift で書いた BabyTap を .app バンドルにパッケージするスクリプト
set -euo pipefail

APP_NAME="BabyTap"
VERSION="2.0.0"
OUT_DIR="release"
APP_DIR="${OUT_DIR}/${APP_NAME}.app"
EXEC_DIR="${APP_DIR}/Contents/MacOS"
RESOURCES_DIR="${APP_DIR}/Contents/Resources"

cd "$(dirname "$0")/.."

echo "==> Swift build (release, arm64)"
swift build -c release --arch arm64

echo "==> Compose .app bundle"
rm -rf "${APP_DIR}"
mkdir -p "${EXEC_DIR}" "${RESOURCES_DIR}"

# 実行バイナリ
cp ".build/release/${APP_NAME}" "${EXEC_DIR}/${APP_NAME}"
chmod +x "${EXEC_DIR}/${APP_NAME}"

# Info.plist
cp "Resources/Info.plist" "${APP_DIR}/Contents/Info.plist"

# PkgInfo (Gatekeeper が期待するファイル)
printf "APPL????" > "${APP_DIR}/Contents/PkgInfo"

# Ad-hoc 署名で TCC (アクセシビリティ等) の永続性を少しでも安定させる
codesign --force --deep --sign - "${APP_DIR}" >/dev/null 2>&1 || true

echo "==> Done: ${APP_DIR}"
ls -la "${APP_DIR}/Contents/"
