#!/usr/bin/env bash
# util_zdp_stdout_manifest.sh — byte-identity manifest that hashes COMPILE STDOUT.  ⛔ NEVER hash the .s beside the .sno: those are COMMITTED ARTIFACTS and hashing them is what made s133 first gate report a fake zero.  Prove the null against itself before any zero is worth anything.
# Byte-identity manifest.  Hashes COMPILE STDOUT, never the committed .s beside the .sno (s133's fake gate).
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
OUT=$1
: > "$OUT"
# ⭐ RE-POINTED 2026-08-30 (seat12, repo-wide dead-suite-path consumer sweep): corpus/probe/ is gone
# (dropped from the sweep); ALL.sno (THE ONE FLAT RUNGS) is explicitly excluded -- it is suite DATA,
# one test per line, never a standalone program, and hashing an attempted whole-file compile of it
# would manifest a few hundred spurious "duplicate label" errors as if they were one file's byte
# identity. Same known limitation as census_zdp_sources.sh: the rungs' own ~1500+ entries are not
# walked by this manifest -- a follow-up, not solved here.
for f in $(find $S4E/corpus/tests/snobol4 -name '*.sno' ! -name 'ALL.sno' | sort); do
    h=$(timeout -k 5 15 ./scrip --compile "$f" < /dev/null 2>/dev/null | md5sum | cut -d' ' -f1)
    echo "$h  $f" >> "$OUT"
done
wc -l < "$OUT"
