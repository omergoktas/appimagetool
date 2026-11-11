#! /bin/bash

set -euxo pipefail

if [[ "${2:-}" == "" ]]; then
    echo "Usage: $0 <version> <hash>"
    exit 2
fi

version="$1"
hash="$2"

build_dir="$(mktemp -d -t mksquashfs-build-XXXXXX)"

cleanup () {
    if [ -d "$build_dir" ]; then
        rm -rf "$build_dir"
    fi
}
trap cleanup EXIT

pushd "$build_dir"

wget -q https://github.com/plougher/squashfs-tools/archive/refs/tags/"$version".tar.gz
echo "${hash}  ${version}.tar.gz" | sha256sum -c
tar xvzf "$version".tar.gz --strip-components=1

cd squashfs-tools

if [[ "${GITHUB_ACTIONS:-}" != "" ]]; then
    jobs="$(nproc)"
else
    jobs="$(nproc --ignore=1)"
fi

make -j"$jobs" GZIP_SUPPORT=0 XZ_SUPPORT=0 LZO_SUPPORT=0 LZ4_SUPPORT=0 ZSTD_SUPPORT=1 COMP_DEFAULT=zstd LDFLAGS=-static USE_PREBUILT_MANPAGES=y install
