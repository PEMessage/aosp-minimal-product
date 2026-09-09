#!/usr/bin/env bash
# LineageOS minimum-product repro (Android 12, lineage-19.1).
# Distro-agnostic: run inside the FHS container (NixOS) or directly (other
# distros). Everything is fetched from Tsinghua mirrors; anything already
# present is skipped. Zero source patches: the 12 build system needs none.
# Verified end-to-end on lineage-19.1: lunch lineage_minimum-eng && m nothing green.
# Idempotent: re-running is a no-op.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOP="${AOSP_TOP:-${HERE}/code}"
BRANCH="${BRANCH:-lineage-19.1}"
JOBS="${JOBS:-8}"

if [ "${LOCAL_ONLY:-0}" = 1 ]; then
    LOCAL_ONLY="--local-only"
else
    LOCAL_ONLY=""
fi

MANIFEST_URL="https://mirrors.tuna.tsinghua.edu.cn/git/lineageOS/LineageOS/android.git"

# -- helpers ---------------------------------------------------------------

need() { command -v "$1" >/dev/null || die "missing: $1"; }
die()  { echo "error: $*" >&2; exit 1; }
repo() { ( cd "$TOP" && command repo "$@" ); }

runcmd() {
    echo "Running: $*"
    "$@"
}

runeval() {
    echo "Running: $*"
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
}

ensure_repo() {
    title
    command -v repo >/dev/null && return 0
    runcmd [ -x "$HOME/bin/repo" ] || {
        runcmd mkdir -p "$HOME/bin"
        runeval python3 -c '
        import urllib.request
        urllib.request.urlretrieve(
            "https://storage.googleapis.com/git-repo-downloads/repo",
            "'"$HOME"'/bin/repo")
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
    # --repo-rev v2.66.1: pin the repo tool to a fixed tag so behavior stays
    #   stable across updates (e.g. the shallow-clone handling below).
    # --no-repo-verify: no gpg in the FHS container, skips tag signature check.
    # --depth 1: shallow-clone every project that lacks an explicit manifest
    #   `clone-depth`. repo 2.66 stores this in repo.depth and applies it to
    #   all such projects, so no clone-depth injection into the manifest is
    #   needed (full-history syncs over a CN mirror are far too slow).
    runcmd repo init -u "$MANIFEST_URL" -b "$BRANCH" \
        --repo-url https://mirrors.ustc.edu.cn/aosp/git-repo.git \
        --repo-rev v2.66.1 \
        --no-repo-verify --no-clone-bundle --depth 1
    # Rewrite remotes to the Tsinghua mirrors.
    runeval "$HERE/scripts/make_manifest.py" \
        "$TOP/.repo/manifests/default.xml" '>' "$TOP/.repo/manifests/default.xml.tuna"
    runcmd mv "$TOP/.repo/manifests/default.xml.tuna" "$TOP/.repo/manifests/default.xml"
}

# Copy the outer repo's local manifests (e.g. local_manifests/kati.xml,
# which brings back external/kati) into the repo workspace. Runs on every
# invocation so updated manifests propagate to already-initialized trees;
# repo picks them up on the next `repo sync`.
install_local_manifests() {
    title
    [[ -d "$TOP/.repo" ]] || return 0
    local xml
    for xml in "$HERE"/local_manifests/*.xml; do
        [[ -e "$xml" ]] || return 0
        runcmd cp "$xml" "$TOP/.repo/local_manifests/"
    done
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
    # Repos soong analysis needs beyond build/ and prebuilts/.
    # external/golang-protobuf: soong_ui microfactory bootstrap.
    # external/starlark-go:     build/make/tools/rbcrun soong module.
    # build/kati:               ckati sources (via local_manifests/kati.xml;
    #                           tweaks are managed with patchman).
    # vendor/lineage:           envsetup + vendormk hooks (required, do not remove).
    local deps
    deps="external/golang-protobuf external/starlark-go build/kati vendor/lineage"
    local missing=()
    for d in $deps; do [[ -d "$TOP/$d" ]] || missing+=("$d"); done
    [[ ${#missing[@]} -eq 0 ]] || runcmd repo sync -c -j "$JOBS" $LOCAL_ONLY "${missing[@]}"
}

# vendor/lineage/prebuilt contains prebuilt blobs (sensitive_pn.xml) that are
# not in the repo. Its soong module is always in the build graph and panics on
# the missing source file, so move the whole dir out of the tree.
quarantine() {
    title
    local src="$1"
    [[ -d "$src" ]] || return 0
    runcmd mkdir -p "$TOP/out/soong/examples-backup"
    runcmd mv "$src" "$TOP/out/soong/examples-backup/"
}

setup_product() {
    title
    local dev="$TOP/device/minimum"
    [[ -f "$dev/AndroidProducts.mk" ]] && return 0
    runcmd mkdir -p "$dev"
    runcmd cp "$HERE"/device/minimum/{AndroidProducts.mk,lineage_minimum.mk,BoardConfig.mk} "$dev/"
}

verify_build() {
    title
    export ALLOW_MISSING_DEPENDENCIES=true
    set +u
    (
        runcmd cd "$TOP"
        runcmd source build/envsetup.sh
        runcmd lunch lineage_minimum-eng
        runcmd m nothing
    )
}

# -- main -------------------------------------------------------------------

main() {
    check_env
    ensure_repo
    init_tree
    install_local_manifests
    sync_core
    sync_deps
    quarantine "$TOP/vendor/lineage/prebuilt"
    setup_product
    verify_build
}

main "$@"
