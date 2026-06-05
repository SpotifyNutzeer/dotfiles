#!/usr/bin/env bash
# Abhängigkeitsfreies Test-Harness. Quelle dies in test_*.sh-Dateien.

TESTS_RUN=0
TESTS_FAILED=0

_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf '  \033[31mFAIL\033[0m %s\n' "$1" >&2
}

_pass() {
    printf '  \033[32mok\033[0m   %s\n' "$1"
}

assert_eq() {
    # assert_eq <actual> <expected> <message>
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$1" == "$2" ]]; then
        _pass "$3"
    else
        _fail "$3 (got '$1', expected '$2')"
    fi
}

assert_symlink_to() {
    # assert_symlink_to <link> <target> <message>
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ -L "$1" && "$(readlink -f "$1")" == "$(readlink -f "$2")" ]]; then
        _pass "$3"
    else
        _fail "$3 ('$1' is not a symlink to '$2')"
    fi
}

assert_contains() {
    # assert_contains <haystack> <needle> <message>
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$1" == *"$2"* ]]; then
        _pass "$3"
    else
        _fail "$3 ('$1' does not contain '$2')"
    fi
}

finish() {
    printf '\n%d run, %d failed\n' "$TESTS_RUN" "$TESTS_FAILED"
    [[ "$TESTS_FAILED" -eq 0 ]]
}
