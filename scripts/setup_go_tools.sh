#!/usr/bin/env bash
# Build gopls + dlv with the tree's prebuilt Go toolchain
# (prebuilts/go/linux-x86) and print the PATH entry to add.
#
# The Android 12 prebuilt Go is go1.15.6. Per gopls' official support policy
# (go.googlesource.com/tools gopls README) the last gopls version that
# supports Go 1.15 is v0.9.5. dlv's last release that still compiles on
# go1.15 is v1.20.1 (v1.21.0 uses os.ReadDir, a Go 1.16 stdlib API). The
# limits below were verified by building each release with the actual prebuilt
# toolchain.
#
#   gopls v0.9.5   (Go 1.15 -> final supported version per the gopls policy)
#   dlv   v1.20.1  (Go 1.15 -> last buildable release; v1.21.0 needs Go 1.16;
#                   note delve tags jump from v1.9.1 to v1.20.0)
#
# dlv v1.20.x targets Go 1.20+ runtimes. It is fine as a standalone dev tool,
# but prefer an older dlv (e.g. v1.7.0) if you need to debug binaries that the
# go1.15.6 toolchain itself compiled.
#
# The binaries are installed next to the prebuilt go binary, so a single PATH
# entry covers go + gopls + dlv:
#   code/prebuilts/go/linux-x86/bin
#
# Network note: modules are fetched via the go module proxy. On a CN network
# set GOPROXY first, e.g. GOPROXY=https://goproxy.cn,direct
#
# Usage:
#   ./scripts/setup_go_tools.sh              # install + print PATH line
#   ./scripts/setup_go_tools.sh --print-path # only print the PATH line
#   eval "$(./scripts/setup_go_tools.sh --print-path)"
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOP="${AOSP_TOP:-$(cd "$HERE/.." && pwd)}"
GO_BIN="$TOP/code/prebuilts/go/linux-x86/bin/go"
GO_BIN_DIR="$(dirname "$GO_BIN")"

# Map a Go minor version to compatible gopls/dlv versions.
# The go1.15 pins follow the gopls support policy and were verified against
# the actual prebuilt toolchain; any other toolchain uses `latest` (the
# @version syntax needs Go >= 1.16).
gopls_version() {
    case "$1" in
        1.15) echo "v0.9.5" ;;
        *)    echo "latest" ;;
    esac
}
dlv_version() {
    case "$1" in
        1.15) echo "v1.20.1" ;;
        *)    echo "latest" ;;
    esac
}

need() { command -v "$1" >/dev/null || die "missing: $1"; }
die()  { echo "error: $*" >&2; exit 1; }

[ -x "$GO_BIN" ] || die "prebuilt go not found at $GO_BIN (run ./bootstrap.sh first)"
need mktemp
need sed

GO_MINOR="$("$GO_BIN" version | sed -n 's/.*go\([0-9]*\.[0-9]*\)\..*/\1/p')"
GOPLS_TARGET="$(gopls_version "$GO_MINOR")"
DLV_TARGET="$(dlv_version "$GO_MINOR")"

print_path() {
    echo "# go=$GO_BIN_DIR ($GO_MINOR) | gopls=$GOPLS_TARGET dlv=$DLV_TARGET"
    echo "export PATH=\"$GO_BIN_DIR:\$PATH\""
}

if [ "${1:-}" = "--print-path" ]; then
    print_path
    exit 0
fi

echo "Using Go: $("$GO_BIN" version)"
echo "Installing to: $GO_BIN_DIR"
echo "Targets: gopls=$GOPLS_TARGET dlv=$DLV_TARGET"

mkdir -p "$GO_BIN_DIR"

# install_module <module> <version> <bin>
# Installs <bin> from <module> at <version> into $GO_BIN_DIR. Skipped if the
# binary already reports that version. For "latest" (unpinned) always
# reinstalls. The go toolchain env vars are exported only inside the build
# subshell, right before their first use, so they cannot leak into the
# caller's environment.
install_module() {
    local pkg="$1" ver="$2" bin_name="$3" ver_str="${2#v}"

    if [ "$ver" != "latest" ] && [ -x "$GO_BIN_DIR/$bin_name" ] \
            && "$GO_BIN_DIR/$bin_name" version 2>/dev/null | grep -q "$ver_str"; then
        echo "  $bin_name: already $("$GO_BIN_DIR/$bin_name" version 2>/dev/null | head -1)"
        return 0
    fi

    local tmp
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/aosp-gotools.XXXXXX")"
    (
        # go toolchain env, scoped to this build, just before first use
        export GOROOT="$TOP/code/prebuilts/go/linux-x86"
        export GOBIN="$GO_BIN_DIR"
        export GO111MODULE=on
        export PATH="$GOROOT/bin:$PATH"

        cd "$tmp"
        go mod init aosp-gotools >/dev/null 2>&1
        go get "$pkg@$ver" >/dev/null
        go install "$pkg" >/dev/null
    )
    rm -rf "$tmp"

    [ -x "$GO_BIN_DIR/$bin_name" ] || die "$bin_name build failed; check the messages above"
    echo "  $bin_name: installed $("$GO_BIN_DIR/$bin_name" version 2>/dev/null | head -1)"
}

echo "== gopls =="
install_module golang.org/x/tools/gopls "$GOPLS_TARGET" gopls

echo "== dlv =="
install_module github.com/go-delve/delve/cmd/dlv "$DLV_TARGET" dlv

echo
print_path
