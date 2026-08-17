#!/usr/bin/env python3
"""Rewrite the LineageOS manifest to use Tsinghua mirrors for both remotes.

The upstream manifest has two remotes:
  github: fetch=".."          -> resolves under the mirror's lineageOS/ tree
  aosp:   fetch=googlesource  -> rewritten here to the Tsinghua AOSP mirror

Prints the rewritten manifest to stdout.
"""

import re
import sys

# Manifest names are "LineageOS/<repo>"; the TUNA mirror stores them under
# lineageOS/LineageOS/<repo>.git, so the fetch base must NOT repeat LineageOS/.
TUNA_LINEAGE = "https://mirrors.tuna.tsinghua.edu.cn/git/lineageOS/"
TUNA_AOSP = "https://mirrors.tuna.tsinghua.edu.cn/git/AOSP/"


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} default.xml", file=sys.stderr)
        return 2

    try:
        content = open(sys.argv[1], encoding="utf-8").read()
    except OSError as e:
        print(f"error: cannot read {sys.argv[1]}: {e}", file=sys.stderr)
        return 1

    # github remote: fetch=".." resolves relative to the manifest URL, which
    # would be TUNA's lineageOS/ tree. Force the absolute base for clarity.
    content = re.sub(
        r'(<remote\s+name="github"[^>]*fetch=")\.\.(")',
        rf'\g<1>{TUNA_LINEAGE}\g<2>',
        content,
    )

    # aosp remote: point at the TUNA AOSP mirror instead of googlesource.
    content = re.sub(
        r'(<remote\s+name="aosp"[^>]*fetch=")https://android\.googlesource\.com(")',
        rf'\g<1>{TUNA_AOSP}\g<2>',
        content,
    )

    sys.stdout.write(content)
    return 0


if __name__ == "__main__":
    sys.exit(main())
