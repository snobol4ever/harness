#!/usr/bin/env bash
# ⛔⛔⛔ WITHDRAWN 2026-09-11 BY LON, CEO-570 -- verbatim: "Do not use Unicon for anything. We do not
# want you getting confused and using it to add semi-colons on the fly versus adding the files to the
# corpus repo." DO NOT RUN THIS. The build it produced (/home/resources/unicon/) is reference material
# only: not an oracle, not a cross-check, not a rival, not a preprocessor. See /home/resources/ORACLES.md
# (the UNICON IS NOT AN ORACLE section) for the two measured reasons -- it DELEGATES to icont, and the
# semicolon-normalizer use Lon forbade would make the graded artifact differ from the committed one.
# Kept on disk as the receipt for what was built and why it was withdrawn, never as a live instrument.
exit 2
# install_unicon_oracle.sh -- build Unicon as the THIRD Icon oracle, beside Arizona icont/iconx and jcon.
# Lon 2026-09-11, in-chat to ceo: "Let's make Unicon a third oracle for our Icon testing and performance
# benchmarks." (CEO-568). Staged for LON TO RUN: the ceo may not build or install under /home/resources
# (the harness classifier refuses it), so this script exists to be run as:  ! bash .github/scripts/install_unicon_oracle.sh
#
# ⛔ THIS IS AN *ADD*, NOT AN ORACLE SWAP. No existing oracle binary is touched, moved or rebuilt. The
# ORACLE-SWAP PROCEDURE (RULES.md § Oracles) governs replacing a shared oracle and does not apply here;
# what does apply is the broadcast and the re-baseline, because a new rival appears in benchmark grids.
# Arizona icont/iconx 9.5.25a REMAINS THE ICON BASELINE (CEO-390: one Icon oracle, one feature set).
# Unicon is a SUPERSET language with its own compiler and runtime -- it accepts programs icont refuses
# (measured: 16 of 26 Benchmarks Game entries), so it can never define what Icon IS for us. Its two jobs:
#   (1) PERFORMANCE RIVAL -- a third engine in Icon benchmark grids beside iconx and SCRIP.
#   (2) CORRECTNESS CROSS-CHECK -- a second opinion where a .std is ambiguous or where our reading of
#       icont's behaviour is the thing in doubt. A disagreement between Unicon and icont is a FINDING to
#       route, never a baseline change. ⛔ If Unicon and icont disagree, ICONT WINS, and the divergence
#       is recorded with both outputs.
set -euo pipefail
DEST=/home/resources/unicon
SRC=https://github.com/uniconproject/unicon.git
say() { printf '\n=== %s\n' "$*"; }
[ -e "$DEST" ] && { echo "⛔ REFUSED: $DEST already exists. This script never overwrites an oracle tree."; echo "   Remove it deliberately, or edit DEST, then re-run."; exit 2; }
command -v gcc >/dev/null || { echo "⛔ REFUSED: no gcc"; exit 2; }
say "cloning $SRC -> $DEST"
git clone --depth=1 "$SRC" "$DEST"
cd "$DEST"
say "configure (no graphics: we want the language, not X11)"
./configure --disable-graphics 2>&1 | tail -5 || { echo "⛔ configure failed -- see output above"; exit 1; }
say "make Unicon (this is a full compiler+runtime build; several minutes)"
make Unicon 2>&1 | tail -20 || { echo "⛔ build failed -- see output above"; exit 1; }
say "verifying the binaries exist and actually run"
UNI="$DEST/bin/unicon"; ICONT_U="$DEST/bin/icont"
for b in "$UNI" "$ICONT_U"; do [ -x "$b" ] || { echo "⛔ REFUSED: expected binary missing: $b"; exit 1; }; done
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
printf 'procedure main()\n  write("unicon_oracle_ok")\nend\n' > "$T/p.icn"
( cd "$T" && "$UNI" -s p.icn -o p.bin >/dev/null 2>&1 && ./p.bin ) | grep -qx unicon_oracle_ok \
  || { echo "⛔ REFUSED: unicon built but could not compile and run a hello program -- NOT installing it as an oracle"; exit 1; }
say "⭐ ORACLE READY"
cat <<EOF
Unicon built at: $DEST
  compiler : $UNI
  version  : $("$UNI" -V 2>&1 | head -1)
NEXT, and none of it is this script's to do:
  1. ceo adds the ICON ORACLE row to /home/resources/ORACLES.md naming this path, its role as
     RIVAL + CROSS-CHECK, and that Arizona icont remains the baseline.
  2. a seat adds unicon_bin() to harness/scripts/lib_oracle_flags.sh beside icont_bin()/iconx_bin(),
     so no script ever assembles this path from memory (the one-path-segment trap, ORACLES.md).
  3. the coo re-baselines Icon benchmark grids with the third arm present; grids gain a column,
     they are NOT re-stamped -- existing numbers keep their own tree labels.
EOF
