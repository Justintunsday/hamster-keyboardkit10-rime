#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
resource_dir="$repo_root/PinyinCore/Sources/PinyinCore/Resources/Rime"
archive_path="${TMPDIR:-/tmp}/rime-ice-2026.06.30-full.zip"
url="https://github.com/iDvel/rime-ice/releases/download/2026.06.30/full.zip"
sha256="675d23b070be00e1b800f9a6db033ef98f4493cd5b568ed8aa3b3541769c46ac"

curl --fail --location --retry 3 "$url" --output "$archive_path"
echo "$sha256  $archive_path" | shasum --algorithm 256 --check --strict

rm -rf "$resource_dir"
mkdir -p "$resource_dir"
ditto -x -k "$archive_path" "$resource_dir"

test -f "$resource_dir/default.yaml"
test -f "$resource_dir/rime_ice.schema.yaml"
test -f "$resource_dir/rime_ice.dict.yaml"
