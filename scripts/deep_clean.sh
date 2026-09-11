#!/usr/bin/env bash
# DeepClean -- drop the code/ working tree, keeping code/.repo/ intact.
#
# `code/` is a `repo` checkout: the working tree is disposable output, while the
# git object stores live in code/.repo/ (project-objects/, projects/).  Dropping
# the working tree and re-syncing `--local-only` rebuilds it without a download.
#
# This script does only the delete half.  Restoring the manifest and re-syncing
# are separate, composable steps, e.g.:
#
#     scripts/deep_clean.sh
#     LOCAL_ONLY=1 ./bootstrap.sh
#
# Usage: scripts/deep_clean.sh [options]   (see --help)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOP="${AOSP_TOP:-$HERE/code}"

die()   { echo "deep_clean: error: $*" >&2; exit 1; }
title() { echo "==> $*"; }

usage() {
    cat <<'EOF'
DeepClean: drop the code/ working tree, keeping code/.repo/ for a local re-sync.

Usage: scripts/deep_clean.sh [options]

Options:
  -n, --dry-run   list what would be removed, change nothing
  -y, --yes       do not prompt for confirmation
  -h, --help      show this help
EOF
}

# -- options ---------------------------------------------------------------

DRY_RUN=0 ASSUME_YES=0
while (( $# )); do
    case "$1" in
        -n|--dry-run) DRY_RUN=1 ;;
        -y|--yes)     ASSUME_YES=1 ;;
        -h|--help)    usage; exit 0 ;;
        *)            die "unknown option: $1 (try --help)" ;;
    esac
    shift
done

# -- preconditions ---------------------------------------------------------

[[ -d "$TOP/.repo" ]] \
    || die "$TOP/.repo missing -- nothing to preserve (run ./bootstrap.sh first)"

# Everything under TOP except .repo is working-tree output and disposable.
mapfile -t WORKTREE < <(
    find "$TOP" -mindepth 1 -maxdepth 1 ! -name .repo -printf '%f\n' | sort
)

# -- delete ----------------------------------------------------------------

drop_worktree() {
    title "drop the working tree, keep .repo/ (${#WORKTREE[@]} entries)"
    if (( ${#WORKTREE[@]} )); then
        printf '    %s\n' "${WORKTREE[@]}"
    fi
    if (( DRY_RUN )); then
        title "dry run: nothing removed"
        return 0
    fi
    if (( ! ASSUME_YES )); then
        [[ -t 0 ]] || die "refusing to delete without -y (stdin is not a tty)"
        read -r -p "remove the above from $TOP? [y/N] " reply
        [[ "$reply" == [yY] ]] || die "aborted"
    fi
    find "$TOP" -mindepth 1 -maxdepth 1 ! -name .repo -exec rm -rf {} +
}

drop_worktree
