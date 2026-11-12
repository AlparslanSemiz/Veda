#!/bin/zsh
# "Veda Local Signing" adında yerel, kendinden imzalı bir kod imzalama sertifikası oluşturur
# ve login anahtar zincirine ekler. build.sh bunu bulursa Veda'yı onunla imzalar; böylece
# imza her derlemede aynı kalır ve macOS Erişilebilirlik iznini sıfırlamaz.
# Sertifika sadece bu Mac'te, sadece codesign tarafından kullanılabilir.
set -euo pipefail
NAME="Veda Local Signing"

if security find-identity -p codesigning 2>/dev/null | grep -q "$NAME"; then
  echo "✓ '$NAME' zaten var."; exit 0
fi

D=$(mktemp -d); trap 'rm -rf "$D"' EXIT
cat > "$D/c.cnf" <<EOF
[req]
distinguished_name=dn
x509_extensions=ext
prompt=no
[dn]
CN=$NAME
[ext]
basicConstraints=critical,CA:false
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
EOF
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -keyout "$D/k.pem" -out "$D/c.pem" -days 3650 -config "$D/c.cnf" 2>/dev/null
P=$(/usr/bin/openssl rand -hex 12)
/usr/bin/openssl pkcs12 -export -inkey "$D/k.pem" -in "$D/c.pem" -out "$D/v.p12" -passout "pass:$P" -name "$NAME" 2>/dev/null
security import "$D/v.p12" -k "$HOME/Library/Keychains/login.keychain-db" -P "$P" -T /usr/bin/codesign >/dev/null
echo "✓ '$NAME' oluşturuldu. Şimdi ./build.sh çalıştırabilirsin."
