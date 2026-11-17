#!/bin/sh
set -eu

name="Celestia Local"
keychain="$HOME/Library/Keychains/login.keychain-db"

if security find-certificate -c "$name" "$keychain" >/dev/null 2>&1; then
    echo "\"$name\" already exists"
    exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cat > "$work/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $name
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CNF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -config "$work/cert.cnf" -keyout "$work/key.pem" -out "$work/cert.pem"
openssl pkcs12 -export -legacy -passout pass:celestia \
    -inkey "$work/key.pem" -in "$work/cert.pem" -out "$work/cert.p12" 2>/dev/null \
    || openssl pkcs12 -export -passout pass:celestia \
        -inkey "$work/key.pem" -in "$work/cert.pem" -out "$work/cert.p12"
security import "$work/cert.p12" -k "$keychain" -P celestia -T /usr/bin/codesign
security add-trusted-cert -p codeSign -k "$keychain" "$work/cert.pem"
echo "\"$name\" created"
