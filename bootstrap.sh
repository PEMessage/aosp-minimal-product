#!/usr/bin/env bash
# LineageOS minimum-product repro (Android 8.1 / 9, lineage-15.1 / 16.0).
# Distro-agnostic: run inside the FHS container (NixOS) or directly (other
# distros). Everything is fetched from Tsinghua mirrors; anything already
# present is skipped. Zero source patches: the 8/9 build system needs none.
# Verified end-to-end on lineage-16.0: lunch minimum-eng && m nothing green.
# Idempotent: re-running is a no-op.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOP="${AOSP_TOP:-${HERE}/code}"
BRANCH="${BRANCH:-lineage-16.0}"   # or lineage-15.1
JOBS="${JOBS:-8}"

if [ "${LOCAL_ONLY}" = 1 ]; then
    LOCAL_ONLY="--local-only"
fi

MANIFEST_URL="https://mirrors.tuna.tsinghua.edu.cn/git/lineageOS/LineageOS/android.git"

# -- helpers ---------------------------------------------------------------

need() { command -v "$1" >/dev/null || die "missing: $1"; }
die()  { echo "error: $*" >&2; exit 1; }
repo() { ( cd "$TOP" && command repo "$@" ); }

runcmd() {
    echo "Runing: $*"
    "$@"
}

runeval() {
    echo "Runing: $*"
    eval "$*"
}

title() {
    echo "=========================="
    echo "${FUNCNAME[1]}"
    echo "=========================="
}

# -- steps -----------------------------------------------------------------

check_env() {
    title

    runcmd need git
    runcmd need python3
    runcmd [ -e /bin/pwd ] || die "/bin/pwd missing - enter the FHS container first (./run.sh)"
    # runcmd [ -d "$TOP/build" ]  || runcmd [ ! -e "$TOP/Android.bp" ] || \
    #     die "$TOP does not look like an AOSP tree (missing build/)"
}

ensure_repo() {
    title
    command -v repo >/dev/null && return 0
    runcmd [ -x "$HOME/bin/repo" ] || {
        runcmd mkdir -p "$HOME/bin"
        runeavl python3 - '<' '
        import urllib.request
        urllib.request.urlretrieve(
            "https://storage.googleapis.com/git-repo-downloads/repo",
            "$HOME/bin/repo")
        '
        runcmd chmod +x "$HOME/bin/repo"
    }
    runeval export PATH="$HOME/bin:$PATH"
}

init_tree() {
    title

    [[ -d "$TOP/.repo" ]] && return 0
    runcmd mkdir -p "$TOP"
    # --repo-url: TUNA does not mirror git-repo; USTC does.
    # --no-repo-verify: no gpg in the FHS container, skips tag signature check.
    runcmd repo init -u "$MANIFEST_URL" -b "$BRANCH" \
        --repo-url https://mirrors.ustc.edu.cn/aosp/git-repo.git \
        --no-repo-verify --no-clone-bundle --depth 1
    # Rewrite remotes to Tsinghua mirrors (aosp remote -> TUNA AOSP).
    runeval "$HERE/scripts/make_manifest.py" \
        "$TOP/.repo/manifests/default.xml" '>' "$TOP/.repo/manifests/default.xml.tuna"
    runcmd mv "$TOP/.repo/manifests/default.xml.tuna" "$TOP/.repo/manifests/default.xml"
}

sync_core() {
    title
    [[ -d "$TOP/build/soong" && -d "$TOP/prebuilts/build-tools" ]] && return 0
    local paths="$TOP/.sync_paths.txt"
    runeval "$HERE/scripts/sync_paths.py" "$TOP" '>' "$paths"
    runcmd repo sync -c -j "$JOBS" $LOCAL_ONLY $(cat "$paths")
}

sync_deps() {
    title
    # Repos soong analysis and kati need even for `m nothing`.
    local deps
    deps="art libcore libnativehelper bionic system/core system/sepolicy
    system/tools/aidl system/tools/hidl external/libcxx external/zlib
    external/protobuf external/googletest toolchain/pgo-profiles
    external/avb external/vboot_reference system/update_engine
    external/clang external/llvm external/python/cpython2 external/icu
    prebuilts/jdk/jdk8 prebuilts/jdk/jdk9 vendor/lineage"
    local missing=()
    for d in $deps; do [[ -d "$TOP/$d" ]] || missing+=("$d"); done
    [[ ${#missing[@]} -eq 0 ]] || runcmd repo sync -c -j "$JOBS" $LOCAL_ONLY "${missing[@]}"
}

# Test dirs whose modules depend on unsynced repos -> move out of the tree.
quarantine() {
    title
    local src="$1"
    [[ -d "$src" ]] || return 0
    runcmd mkdir -p "$TOP/out/soong/examples-backup"
    runcmd mv "$src" "$TOP/out/soong/examples-backup/"
}

# LineageOS 16.0 kati only accepts test_current/core_current; several repos
# still use the legacy "current" (tests only, not needed for m nothing).
fix_legacy_sdk_versions() {
    title
    local f
    for f in \
        external/protobuf/Android.mk \
        libcore/metrictests/memory/apps/Android.mk \
        system/core/libnativeloader/test/Android.mk; do
        [[ -f "$TOP/$f" ]] || continue
        runcmd sed -i 's/LOCAL_SDK_VERSION := current/LOCAL_SDK_VERSION := test_current/' "$TOP/$f"
        runcmd sed -i 's/LOCAL_SDK_VERSION := 8/LOCAL_SDK_VERSION := test_current/' "$TOP/$f"
    done
    # art/tools/amm: test-only modules break kati; keep the file (hard-included
    # by art/Android.mk) but strip its modules.
    local amm="$TOP/art/tools/amm/Android.mk"
    if [[ -f "$amm" ]] && grep -q 'LOCAL_MODULE :=' "$amm"; then
        runcmd sed -i 's/^\([^#].*\)$/# \1/' "$amm"
    fi
}

# vendor/lineage/vendorsetup.sh curls githubusercontent to list build targets;
# unreachable in CN networks -> hang. Add a hard timeout.
fix_vendorsetup() {
    title
    local f="$TOP/vendor/lineage/vendorsetup.sh"
    [[ -f "$f" ]] || return 0
    runcmd sed -i 's/curl -s https:\/\/raw.githubusercontent.com/curl -s --max-time 5 https:\/\/raw.githubusercontent.com/' "$f"
}

setup_product() {
    title
    local dev="$TOP/device/minimum"
    [[ -f "$dev/AndroidProducts.mk" ]] && return 0
    runcmd mkdir -p "$dev"
    runcmd cp "$HERE"/device/minimum/{AndroidProducts.mk,minimum.mk,BoardConfig.mk} "$dev/"
}

verify_build() {
    title
    export ALLOW_MISSING_DEPENDENCIES=true
    set +u
    (
        runcmd cd "$TOP"
        runcmd source build/envsetup.sh
        runcmd lunch minimum-eng
        runcmd m nothing
    )
}

# -- main -------------------------------------------------------------------

main() {
    check_env
    ensure_repo
    init_tree
    sync_core
    sync_deps
    quarantine "$TOP/system/tools/hidl/test"   # needs unsynced HIDL interfaces
    fix_legacy_sdk_versions
    fix_vendorsetup
    setup_product
    verify_build

}

main "$@"
