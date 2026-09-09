#!/usr/bin/env bash
# encoding: utf-8
set -e

OUTPUT="${PWD}/Frameworks"

# 下载依赖的 librime framework。
# imfuxiao/LibrimeKit no longer has a release endpoint. The available
# compatible fork publishes the same Frameworks.tgz layout as v0.1.0.
LibrimeKitRepository="amorphobia/LibrimeKit"
LibrimeKitVersion="v0.1.0"
ArchiveURL="https://github.com/${LibrimeKitRepository}/releases/download/${LibrimeKitVersion}/Frameworks.tgz"
ArchiveSHA256="7B3D1D210C5A251A951685B722399C5EEB60F18A39A782A8850511EDD12D0398"

mkdir -p "${OUTPUT}"
ArchivePath="$(mktemp "${TMPDIR:-/tmp}/hamster-frameworks.XXXXXX")"
cleanup() {
  rm -f "${ArchivePath}"
}
trap cleanup EXIT

curl --fail --show-error --location --retry 3 --retry-delay 2 \
  --connect-timeout 30 --output "${ArchivePath}" "${ArchiveURL}"

ArchiveDigest="$(shasum -a 256 "${ArchivePath}" | awk '{print toupper($1)}')"
if [ "${ArchiveDigest}" != "${ArchiveSHA256}" ]; then
  echo "Frameworks.tgz SHA-256 mismatch: expected ${ArchiveSHA256}, got ${ArchiveDigest}" >&2
  exit 1
fi

# Validate the response before removing any existing local frameworks.
tar -tzf "${ArchivePath}" >/dev/null
for framework in \
  boost_atomic boost_filesystem boost_regex boost_system \
  libglog libleveldb libmarisa libopencc libyaml-cpp librime; do
  tar -tzf "${ArchivePath}" "Frameworks/${framework}.xcframework/" >/dev/null
done

rm -rf "${OUTPUT}"/*.xcframework
tar -xzf "${ArchivePath}" -C "${OUTPUT}/.."