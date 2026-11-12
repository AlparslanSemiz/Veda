#!/bin/zsh
# Veda'yı derler, ~/Applications/Veda.app olarak kurar ve girişte başlatır.
#   ./build.sh            -> derle + kur + başlat
#   ./build.sh --no-install -> sadece build/Veda.app üret
set -euo pipefail
cd "${0:A:h}"

BUNDLE_ID="${VEDA_BUNDLE_ID:-local.$(whoami).veda}"
BUILD=build
APP="$BUILD/Veda.app"

rm -rf "$BUILD"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$BUILD/Veda.iconset"

echo "→ simge"
swift scripts/make_icon.swift "$BUILD/icon.png"
for s in 16 32 128 256 512; do
  sips -z $s $s "$BUILD/icon.png" --out "$BUILD/Veda.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$BUILD/icon.png" --out "$BUILD/Veda.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$BUILD/Veda.iconset" -o "$APP/Contents/Resources/Veda.icns"

echo "→ derleme"
swiftc -O Sources/main.swift -o "$APP/Contents/MacOS/Veda"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleName</key><string>Veda</string>
<key>CFBundleDisplayName</key><string>Veda</string>
<key>CFBundleExecutable</key><string>Veda</string>
<key>CFBundleIconFile</key><string>Veda</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSUIElement</key><true/>
<key>NSHumanReadableCopyright</key><string>Son pencere veda edince uygulama da gider.</string>
</dict></plist>
EOF
SIGN_ID="-"
if security find-identity -p codesigning 2>/dev/null | grep -q "Veda Local Signing"; then
  SIGN_ID="Veda Local Signing"
else
  echo "  (not: scripts/make_signing_cert.sh çalıştırılmamış, ad-hoc imza kullanılıyor)"
fi
codesign --force -s "$SIGN_ID" --identifier "$BUNDLE_ID" "$APP"

[[ "${1:-}" == "--no-install" ]] && { echo "✓ $APP"; exit 0; }

echo "→ kurulum"
DEST="$HOME/Applications/Veda.app"
PLIST="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"
DOMAIN="gui/$(id -u)"
launchctl bootout "$DOMAIN/$BUNDLE_ID" 2>/dev/null || true
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents"
rm -rf "$DEST"; cp -R "$APP" "$DEST"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>$BUNDLE_ID</string>
<key>ProgramArguments</key><array><string>$DEST/Contents/MacOS/Veda</string></array>
<key>RunAtLoad</key><true/>
<key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
<key>ProcessType</key><string>Interactive</string>
<key>StandardErrorPath</key><string>$HOME/Library/Logs/veda.log</string>
</dict></plist>
EOF
launchctl bootstrap "$DOMAIN" "$PLIST"
echo "✓ Veda kuruldu ve çalışıyor."
echo "  Yeniden derlemeden sonra imza değiştiği için Erişilebilirlik iznini tekrar vermen gerekebilir:"
echo "  Sistem Ayarları → Gizlilik ve Güvenlik → Erişilebilirlik → Veda"
