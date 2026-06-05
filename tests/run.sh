#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

rc=0
for t in test_*.sh; do
    [[ -e "$t" ]] || continue
    printf '\033[1m== %s ==\033[0m\n' "$t"
    bash "$t" || rc=1
done
exit "$rc"
