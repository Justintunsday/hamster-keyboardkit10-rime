#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
resource_dir="$repo_root/PinyinCore/Sources/PinyinCore/Resources/Rime"
archive_path="${TMPDIR:-/tmp}/rime-ice-2026.06.30-full.zip"
url="https://github.com/iDvel/rime-ice/releases/download/2026.06.30/full.zip"
sha256="675d23b070be00e1b800f9a6db033ef98f4493cd5b568ed8aa3b3541769c46ac"
opencc_commit="1d8105a0f7199c90af722bff62728050c858e777"
opencc_base_url="https://raw.githubusercontent.com/ddddxxx/SwiftyOpenCC/$opencc_commit/Sources/OpenCC/Dictionary"
opencc_characters_sha256="AABED624D0576B8D6A8FF6C143FB37B432DD5A4FF421260172E691679FC43FE9"
opencc_phrases_sha256="2E68E25F2385936970E2ABA9AC71A873BC9A3AB426E3A69251E3048C6A508141"

curl --fail --location --retry 3 "$url" --output "$archive_path"
echo "$sha256  $archive_path" | shasum --algorithm 256 --check --strict

rm -rf "$resource_dir"
mkdir -p "$resource_dir"
ditto -x -k "$archive_path" "$resource_dir"
cp "$repo_root/scripts/rime_ice.mobile.schema.yaml" "$resource_dir/rime_ice.schema.yaml"
mkdir -p "$resource_dir/opencc"
cp "$repo_root/scripts/rime_ice.mobile.s2t.json" "$resource_dir/opencc/s2t.json"
curl --fail --location --retry 3 "$opencc_base_url/STCharacters.ocd2" --output "$resource_dir/opencc/STCharacters.ocd2"
curl --fail --location --retry 3 "$opencc_base_url/STPhrases.ocd2" --output "$resource_dir/opencc/STPhrases.ocd2"
echo "$opencc_characters_sha256  $resource_dir/opencc/STCharacters.ocd2" | shasum --algorithm 256 --check --strict
echo "$opencc_phrases_sha256  $resource_dir/opencc/STPhrases.ocd2" | shasum --algorithm 256 --check --strict

test -f "$resource_dir/default.yaml"
test -f "$resource_dir/rime_ice.schema.yaml"
test -f "$resource_dir/rime_ice.dict.yaml"
test -f "$resource_dir/cn_dicts/8105.dict.yaml"
test -f "$resource_dir/cn_dicts/base.dict.yaml"
test -f "$resource_dir/cn_dicts/ext.dict.yaml"
test -f "$resource_dir/cn_dicts/tencent.dict.yaml"
test -f "$resource_dir/cn_dicts/others.dict.yaml"
test -f "$resource_dir/melt_eng.schema.yaml"
test -f "$resource_dir/radical_pinyin.schema.yaml"
test -f "$resource_dir/opencc/s2t.json"
test -f "$resource_dir/opencc/STCharacters.ocd2"
test -f "$resource_dir/opencc/STPhrases.ocd2"
grep -Fq 'dictionary: rime_ice' "$resource_dir/rime_ice.schema.yaml"
grep -Fq 'enable_user_dict: true' "$resource_dir/rime_ice.schema.yaml"
grep -Fq 'simplifier@traditionalize' "$resource_dir/rime_ice.schema.yaml"
grep -Fq 'opencc_config: s2t.json' "$resource_dir/rime_ice.schema.yaml"
! grep -Eq '^[[:space:]]*-[[:space:]]+lua_' "$resource_dir/rime_ice.schema.yaml"
