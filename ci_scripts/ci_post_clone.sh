#!/bin/sh

#  ci_post_clone.sh
#  Hamster
#
#  Created by morse on 2023/9/28.
#
set -e

REPOSITORY_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$PWD}"

# Download the pinned, compatible librime XCFramework archive. The shared
# script validates the archive before replacing any existing frameworks.
(
  cd "${REPOSITORY_ROOT}"
  bash ./librimeFramework.sh
)

# Generate SharedSupport.zip and rime-ice.zip.
OUTPUT="${REPOSITORY_ROOT}/Resources/SharedSupport"
mkdir -p "${OUTPUT}"
(
  cd "${REPOSITORY_ROOT}"
  bash ./InputSchemaBuild.sh
)
cp "${REPOSITORY_ROOT}/.tmp/SharedSupport/SharedSupport.zip" "${OUTPUT}"
cp "${REPOSITORY_ROOT}/.tmp/.rime-ice/rime-ice.zip" "${OUTPUT}"