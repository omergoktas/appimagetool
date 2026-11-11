#! /bin/bash

set -euxo pipefail

if [[ "${ARCH:-}" == "" ]]; then
    echo "Usage: env ARCH=... bash $0"
    exit 1
fi

build_dir="$(mktemp -d -t appimagetool-build-XXXXXX)"

cleanup () {
    if [ -d "$build_dir" ]; then
        rm -rf "$build_dir"
    fi
}
trap cleanup EXIT

# store repo root as variable
repo_root="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")"/..)"
old_cwd="$(readlink -f "$PWD")"

pushd "$build_dir"

cmake "$repo_root" -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_STATIC=ON

if [[ "${GITHUB_ACTIONS:-}" != "" ]]; then
    jobs="$(nproc)"
else
    jobs="$(nproc --ignore=1)"
fi

make -j"$jobs"

make install DESTDIR=AppDir

find AppDir

cp "$(which desktop-file-validate)" AppDir/usr/bin
cp "$(which mksquashfs)" AppDir/usr/bin
cp "$(which zsyncmake)" AppDir/usr/bin

cp "$repo_root"/resources/AppRun.sh AppDir/AppRun
chmod +x AppDir/AppRun

# The runtime this AppImage is packed with: release 20251108-1 of this
# account's fork of type2-runtime, checked against its SHA-256.
case "$ARCH" in
    x86_64)
        runtime_hash=7afaed97f0ea1c30c68e6beb3a0528db4398fe4e6b4f1a23f2077957277fecdf
        ;;
    aarch64)
        runtime_hash=10d582ecc70c2836afee511cfc79ea6e8733ca686cb2258d86b3c4fec1b84b0b
        ;;
    *)
        echo "no runtime is pinned for architecture: $ARCH"
        exit 2
        ;;
esac
wget https://github.com/omergoktas/type2-runtime/releases/download/20251108-1/runtime-"$ARCH"
echo "${runtime_hash}  runtime-${ARCH}" | sha256sum -c

pushd AppDir
ln -s usr/share/applications/appimagetool.desktop .
ln -s usr/share/icons/hicolor/128x128/apps/appimagetool.png .
ln -s usr/share/icons/hicolor/128x128/apps/appimagetool.png .DirIcon
popd

find AppDir
cat AppDir/appimagetool.desktop

AppDir/AppRun --runtime-file runtime-"$ARCH" AppDir

mv appimagetool-*.AppImage "$old_cwd"
