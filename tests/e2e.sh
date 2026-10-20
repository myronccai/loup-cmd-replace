#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte), and where given its standard error, and exit status with
# the expected ones. The cases run inside a fixture tree built under $TMP.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
# If $WANT_ERR is set, standard error must equal it too.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    local err_ok=1
    if [ -n "${WANT_ERR+set}" ]; then
        printf '%s' "$WANT_ERR" > "$TMP/want_err"
        cmp -s "$TMP/want_err" "$TMP/err" || err_ok=0
    fi
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out" && [ "$err_ok" -eq 1 ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        if [ "$err_ok" -eq 0 ]; then
            diff <(od -c "$TMP/want_err") <(od -c "$TMP/err") | sed 's/^/    stderr /' | head -20
        fi
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_both NAME STATUS EXPECTED_STDOUT EXPECTED_STDERR [ARGS...]
check_both() {
    local name=$1 want_status=$2 want_out=$3
    local WANT_ERR=$4
    shift 4
    check "$name" "$want_status" "$want_out" "$@"
}

# check_contents NAME FILE EXPECTED: a file's contents after a run.
check_contents() {
    printf '%s' "$3" > "$TMP/want_contents"
    if cmp -s "$TMP/want_contents" "$2"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $1 (contents of $2)"
    fi
}

# The fixture tree, rebuilt before each case that changes it.
W="$TMP/w"
reset() {
    cd "$TMP" || exit 1
    rm -rf "$W"
    mkdir -p "$W/src/inner" "$W/dst/sub/deep" "$W/dst/Zed" "$W/dst/sub/c.log"
    printf 'new a\n' > "$W/src/a.txt"
    printf 'new b\n' > "$W/src/b.txt"
    printf 'new c\n' > "$W/src/c.log"
    printf 'old a\n' > "$W/dst/a.txt"
    printf 'new b\n' > "$W/dst/b.txt"
    printf 'old z\n' > "$W/dst/z.txt"
    printf 'old sub a\n' > "$W/dst/sub/a.txt"
    printf 'old deep a\n' > "$W/dst/sub/deep/a.txt"
    printf 'old Zed a\n' > "$W/dst/Zed/a.txt"
    cd "$W" || exit 1
}
HELP="$(cd "$(dirname "$0")" && pwd)/fixtures/help.txt"
reset

# Messages show full paths with `\`.
NL=$'\n'
WD=${W//\//\\}
D="$WD\\dst"

# Help and version.
WANT_ERR='' check_file "/? help"   0 "$HELP"                    '/?'
check_file "-? help"                0 "$HELP"                   a b '-?'
check_file "--help"                 0 "$HELP"                   --help
check      "--version"              0 $'replace (loup-cmd-replace) 0.1.0\n' --version

# Replacing.
check_both "replace two"            0 "${NL}Replacing $D\\a.txt${NL}${NL}Replacing $D\\b.txt${NL}${NL}2 file(s) replaced${NL}" '' \
    'src\*.txt' dst
check_contents "replaced a"         dst/a.txt $'new a\n'
check_contents "z untouched"        dst/z.txt $'old z\n'
reset
cd dst
check      "default destination"    0 "${NL}Replacing $D\\a.txt${NL}${NL}1 file(s) replaced${NL}" '..\src\a.txt'
cd "$W"
reset
check      "/U skips equal files"   0 "${NL}Replacing $D\\a.txt${NL}${NL}1 file(s) replaced${NL}" 'src/*.txt' dst /U
check      "/U again: nothing"      0 "${NL}No files replaced${NL}" 'src/*.txt' dst /u
reset
check      "/S order"               0 "${NL}Replacing $D\\a.txt${NL}${NL}Replacing $D\\sub\\a.txt${NL}${NL}Replacing $D\\sub\\deep\\a.txt${NL}${NL}Replacing $D\\Zed\\a.txt${NL}${NL}4 file(s) replaced${NL}" \
    'src\a.txt' dst /S
check_contents "/S deep"            dst/sub/deep/a.txt $'new a\n'
check      "/S skips directories"   0 "${NL}No files replaced${NL}" 'src\c.log' dst /s
check      "not in destination"     0 "${NL}No files replaced${NL}" 'src\c.log' dst
check_both "onto itself"            0 "${NL}No files replaced${NL}" $'File cannot be copied onto itself\n' 'dst\z.txt' dst
check_both "onto itself via .."     0 "${NL}No files replaced${NL}" $'File cannot be copied onto itself\n' 'dst/sub/../z.txt' 'dst\'

# Adding.
reset
check      "/A adds missing"        0 "${NL}Adding $D\\c.log${NL}${NL}1 file(s) added${NL}" 'src\*' dst /A
check_contents "added c.log"        dst/c.log $'new c\n'
check_contents "/A leaves a"        dst/a.txt $'old a\n'
check      "/A nothing to add"      0 "${NL}No files added${NL}" 'src\*' dst /a

# Read-only files.
reset
chmod a-w dst/a.txt
check_both "read-only"              5 "${NL}Replacing $D\\a.txt${NL}" "Access denied - $D\\a.txt${NL}" 'src\a.txt' dst
check_contents "read-only kept"     dst/a.txt $'old a\n'
check      "/R"                     0 "${NL}Replacing $D\\a.txt${NL}${NL}1 file(s) replaced${NL}" 'src\a.txt' dst /R
check_contents "/R replaced"        dst/a.txt $'new a\n'

# /P and /W read standard input.
reset
printf 'maybe\nn\ny\n' > "$TMP/answers"
IN="$TMP/answers" check "/P" 0 "${NL}Replace $D\\a.txt? (Y/N)maybe${NL}${NL}Replace $D\\a.txt? (Y/N)N${NL}${NL}Replace $D\\b.txt? (Y/N)Y${NL}${NL}Replacing $D\\b.txt${NL}${NL}1 file(s) replaced${NL}" \
    'src\*.txt' dst /P
check_contents "/P no"              dst/a.txt $'old a\n'
check      "/P end of input"        0 "${NL}Add $D\\c.log? (Y/N)${NL}${NL}No files added${NL}" 'src\*' dst /A /P
printf 'x' > "$TMP/key"
IN="$TMP/key" check "/W"            0 "Press any key to continue . . .${NL}${NL}Replacing $D\\a.txt${NL}${NL}1 file(s) replaced${NL}" \
    'src\a.txt' dst /W

# Errors.
check_both "no source"              11 '' $'Source path required\n'
check_both "too many"               11 '' $'Too many parameters - c\n'   a b c
check_both "invalid switch"         11 '' $'Invalid switch - /x\n'       'src\a.txt' /x
check_both "repeated switch"        11 '' $'Invalid switch - /S\n'       'src\a.txt' /s /S
check_both "/A with /S"             11 '' $'Invalid parameter combination\n' 'src\a.txt' /A /S
check_both "/A with /U"             11 '' $'Invalid parameter combination\n' 'src\a.txt' /u /a
check_both "no source match"        2  '' "${NL}No files found - $WD\\src\\*.none${NL}" 'src\*.none' dst
check_both "source is a directory"  2  '' "${NL}No files found - $WD\\src\\inner${NL}" 'src\inner' dst
check_both "source dir missing"     3  '' "Path not found - $WD\\nodir\\a.txt${NL}" 'nodir\a.txt' dst
check_both "wildcard in directory"  3  '' "Path not found - $WD\\s*\\a.txt${NL}" 's*\a.txt' dst
check_both "destination missing"    3  '' "Path not found - $WD\\nodest${NL}" 'src\a.txt' nodest
check_both "-- ends switches"       2  '' "${NL}No files found - \\x${NL}" -- /x dst

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
