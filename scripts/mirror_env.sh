#!/bin/sh
# Source this file to route the canonical upstreams through the MirrorZ union
# URLs for git/repo commands in the current shell:
#
#     . scripts/mirror_env.sh
#
# It is sourced by bootstrap.sh and the nix dev shell (flake.nix), so the
# rewrite is scoped to this project's environment instead of the user's
# ~/.gitconfig.  The mechanism is git's environment config (GIT_CONFIG_COUNT /
# GIT_CONFIG_KEY_n / GIT_CONFIG_VALUE_n); every git subprocess repo spawns
# inherits it.  POSIX sh, and idempotent: sourcing twice adds nothing.
#
# See https://help.mirrors.cernet.edu.cn/lineageOS/ and .../AOSP/.

if [ -n "${MIRROR_ENV_SOURCED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
export MIRROR_ENV_SOURCED=1

_mirror_n="${GIT_CONFIG_COUNT:-0}"

eval "export GIT_CONFIG_KEY_${_mirror_n}='url.https://mirrors.cernet.edu.cn/AOSP/.insteadOf'"
eval "export GIT_CONFIG_VALUE_${_mirror_n}='https://android.googlesource.com'"
_mirror_n=$((_mirror_n + 1))

# Scope the github rewrite to the LineageOS org instead of all of github.com:
# the MirrorZ /lineageOS/ mirror only carries LineageOS/*, so a bare
# `github.com/` prefix would silently misroute any other owner (e.g.
# github.com/TheMuppets/...) to a 404.  Add one pair per extra owner here if a
# manifest ever needs one; the base must repeat the owner because insteadOf
# replaces the matched prefix verbatim.
eval "export GIT_CONFIG_KEY_${_mirror_n}='url.https://mirrors.cernet.edu.cn/lineageOS/LineageOS.insteadOf'"
eval "export GIT_CONFIG_VALUE_${_mirror_n}='https://github.com/LineageOS'"
_mirror_n=$((_mirror_n + 1))

export GIT_CONFIG_COUNT="$_mirror_n"
unset _mirror_n
