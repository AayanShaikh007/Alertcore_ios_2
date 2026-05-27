#!/bin/sh
set -eu

IPA_PATH="${1:-}"

if [ -z "$IPA_PATH" ]; then
  echo "Usage: $(basename "$0") /path/to/App.ipa" >&2
  exit 1
fi

if [ ! -f "$IPA_PATH" ]; then
  echo "IPA not found: $IPA_PATH" >&2
  exit 1
fi

if ! file "$IPA_PATH" | grep -Eq 'Zip archive data|ZIP archive data'; then
  echo "IPA is not a ZIP archive: $IPA_PATH" >&2
  file "$IPA_PATH" >&2 || true
  exit 1
fi

magic_hex="$(LC_ALL=C head -c 4 "$IPA_PATH" | od -An -tx1 | tr -d ' \n')"
case "$magic_hex" in
  504b0304|504b0506|504b0708)
    ;;
  *)
    echo "IPA does not start with a ZIP signature: $IPA_PATH" >&2
    echo "First 4 bytes: $magic_hex" >&2
    exit 1
    ;;
esac

unzip -l "$IPA_PATH" | grep -Eq 'Payload/.+\.app/Info\.plist'

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/alertcore-ipa.XXXXXX")"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

unzip -q "$IPA_PATH" -d "$tmp_dir"
info_plist="$(find "$tmp_dir/Payload" -path '*.app/Info.plist' | head -n 1)"

if [ -z "$info_plist" ]; then
  echo "Could not find bundled Info.plist inside the IPA." >&2
  exit 1
fi

/usr/bin/plutil -lint "$info_plist"

echo "IPA validation passed: $IPA_PATH"