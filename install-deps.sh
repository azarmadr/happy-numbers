#!/usr/bin/env bash
EXCLUDE="--exclude=JSON::Fast:ver<0.19+>:auth<cpan:TIMOTIMO>"

patch_openssl() {
  for dir in $(ls -d /tmp/.zef.*/*/OpenSSL-*/resources 2>/dev/null); do
    if [ ! -f "$dir/libraries.json" ]; then
      echo '{"crypto":"crypto","ssl":"ssl"}' > "$dir/libraries.json"
      echo "Patched: $dir/libraries.json"
    fi
  done
}

echo "=== Re-installing UUID::V4 (ensure staged) ==="
zef install "UUID::V4:auth<zef:masukomi>" --force-install --/test $EXCLUDE && echo "=== UUID::V4 DONE ===" || echo "=== UUID::V4 FAILED ==="

echo "=== Installing Cro::WebSocket ==="
patch_openssl
zef install "Cro::WebSocket:auth<zef:cro>" --force-install --/test $EXCLUDE && echo "=== Cro::WebSocket DONE ===" || echo "=== Cro::WebSocket FAILED ==="

echo "=== Installing CSS::Nested ==="
zef install "CSS::Nested:auth<zef:FCO>" --/test && echo "=== CSS::Nested DONE ===" || echo "=== CSS::Nested FAILED ==="

echo "=== Installing Cromponent ==="
patch_openssl
zef install "Cromponent:auth<zef:FCO>" --force-install --/test $EXCLUDE && echo "=== Cromponent DONE ===" || echo "=== Cromponent FAILED ==="

echo "=== Installing Air ==="
patch_openssl
zef install "Air:auth<zef:librasteve>" --force-install --/test $EXCLUDE && echo "=== Air DONE ===" || echo "=== Air FAILED ==="

echo "=== ALL DONE ==="
