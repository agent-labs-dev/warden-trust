#!/bin/sh
# Checks the trust record: the grammar of ROOTS.txt and WITHDRAWALS.txt in HEAD-DIR, and that they only add lines
# to the same files in BASE-DIR (a file missing from BASE-DIR is new). Reads only; prints the first fault.
# Usage: sh tools/check-record.sh BASE-DIR HEAD-DIR
set -eu
base=$1 head=$2
fail() { printf 'check-record: %s\n' "$1" >&2; exit 1; }

# Printable ASCII and LF only, not empty, at most 65,536 bytes, a newline at the end.
text() {
  [ -f "$head/$1" ] || fail "$1 is missing."
  n=$(wc -c <"$head/$1" | tr -d ' ')
  [ "$n" -gt 0 ] && [ "$n" -le 65536 ] || fail "$1 is empty or over 65536 bytes."
  [ "$(LC_ALL=C tr -d '\n -~' <"$head/$1" | wc -c | tr -d ' ')" = 0 ] || fail "$1 has a byte other than printable ASCII and LF."
  [ "$(tail -c 1 "$head/$1" | od -An -tx1 | tr -d ' \n')" = 0a ] || fail "$1 does not end with a newline."
}

# The base file without its last KEEP lines must be the first lines of the head file, byte for byte.
kept() {
  [ -f "$base/$1" ] || return 0
  n=$(($(wc -l <"$base/$1") - $2))
  [ "$(head -n "$n" "$base/$1" | od -An -tx1)" = "$(head -n "$n" "$head/$1" | od -An -tx1)" ] ||
    fail "$1 removes, changes or moves a line that $3. Lines are only added."
}

text ROOTS.txt
LC_ALL=C awk '
  NR == 1 && $0 !~ /^root 1 sha256 / { bad = 1 }
  !(NF == 4 && $1 == "root" && $2 ~ /^[1-9][0-9]*$/ && $3 == "sha256" && $4 ~ /^[0-9a-f]+$/ && length($4) == 64) &&
    !(NF == 3 && $1 == "installer" && $2 == "sha256" && $3 ~ /^[0-9a-f]+$/ && length($3) == 64) { bad = 1 }
  $0 ~ /^ | $|  / || seen[$0]++ { bad = 1 }
  END { exit bad }' "$head/ROOTS.txt" || fail "ROOTS.txt has a line outside its grammar or a line twice."
kept ROOTS.txt 0 "main has"

# The installer reads WITHDRAWALS.txt with this same grammar (src/install/install-next.sh on the website).
text WITHDRAWALS.txt
LC_ALL=C awk '
  NR == 1 { if ($0 != "wardensec-withdrawals 1") bad = 1; next }
  ended { bad = 1; next }
  $0 == "end" { ended = 1; next }
  $0 !~ /^withdraw [1-9][0-9]*$/ || length($2) > 9 || seen[$2]++ { bad = 1 }
  END { exit (bad || !ended) }' "$head/WITHDRAWALS.txt" || fail "WITHDRAWALS.txt has a line outside its grammar or a sequence twice."
kept WITHDRAWALS.txt 1 "main has before end"
echo "check-record: ok"
