#!/bin/sh
# Shows that tools/check-record.sh passes appended lines and refuses every removed, changed or moved line.
# Usage: sh tools/check-record.test.sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
t=$(mktemp -d) && trap 'rm -rf "$t"' EXIT
H=$(printf 'a%.0s' 1 2 3 4 | sed 's/a/0123456789abcdef/g')
roots="root 1 sha256 $H
installer sha256 $(printf '%s' "$H" | tr 0 1)"
w() { printf 'wardensec-withdrawals 1\n'; for s in "$@"; do printf 'withdraw %s\n' "$s"; done; printf 'end\n'; }
fails=0
case_() { # name expect(ok|refuse) base-roots base-withdrawals head-roots head-withdrawals: each without its last newline, "-" for no file
  rm -rf "$t/b" "$t/h" && mkdir "$t/b" "$t/h"
  [ "$3" = - ] || printf '%s\n' "$3" >"$t/b/ROOTS.txt"
  [ "$4" = - ] || printf '%s\n' "$4" >"$t/b/WITHDRAWALS.txt"
  [ "$5" = - ] || printf '%s\n' "$5" >"$t/h/ROOTS.txt"
  [ "$6" = - ] || printf '%s\n' "$6" >"$t/h/WITHDRAWALS.txt"
  if sh "$here/check-record.sh" "$t/b" "$t/h" >/dev/null 2>&1; then got=ok; else got=refuse; fi
  [ "$got" = "$2" ] || { echo "FAIL: $1 (expected $2, got $got)"; fails=$((fails + 1)); }
}
W0=$(w) W1=$(w 4) W2=$(w 4 7)
case_ "unchanged" ok "$roots" "$W1" "$roots" "$W1"
case_ "first record" ok "$roots" - "$roots" "$W0"
case_ "append a withdrawal" ok "$roots" "$W1" "$roots" "$W2"
case_ "append an installer" ok "$roots" "$W1" "$roots
installer sha256 $(printf '%s' "$H" | tr 0 2)" "$W1"
case_ "delete a withdrawal" refuse "$roots" "$W2" "$roots" "$W1"
case_ "edit a withdrawal" refuse "$roots" "$W1" "$roots" "$(w 5)"
case_ "reorder withdrawals" refuse "$roots" "$W2" "$roots" "$(w 7 4)"
case_ "delete the file" refuse "$roots" "$W1" "$roots" -
case_ "line after end" refuse "$roots" "$W1" "$roots" "$W1
withdraw 7"
case_ "duplicate sequence" refuse "$roots" "$W1" "$roots" "$(w 4 4)"
case_ "leading zero" refuse "$roots" "$W0" "$roots" "$(w 04)"
case_ "unknown line" refuse "$roots" "$W0" "$roots" "wardensec-withdrawals 1
revoke 4
end"
case_ "CRLF" refuse "$roots" "$W0" "$roots" "$(printf 'wardensec-withdrawals 1\r\nend\r')"
case_ "missing end" refuse "$roots" "$W0" "$roots" "wardensec-withdrawals 1"
case_ "delete a root line" refuse "$roots" "$W1" "root 1 sha256 $H" "$W1"
case_ "edit a root line" refuse "$roots" "$W1" "root 1 sha256 $(printf '%s' "$H" | tr 0 3)
installer sha256 $(printf '%s' "$H" | tr 0 1)" "$W1"
[ "$fails" = 0 ] || exit 1
echo "check-record test: ok"
