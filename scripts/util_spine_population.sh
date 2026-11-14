#!/usr/bin/env bash
# util_spine_population.sh -- THE ONE POPULATION the spine counts are taken over (R-1855/1856): every benchmark and demo program that carries
# a committed .s artifact (SNOBOL4, Icon, Prolog) plus every Pascal, Raku, Snocone and Rebus demo and benchmark source. One line per program:
#   <lang> <TAB> <absolute source path>
# Read by util_placement_watch.sh, test_gate_no_rsp_reset_at_beta.sh and test_gate_no_spine_preallocation.sh, so the watch's line and the gates
# that close the rows count the same programs.
# A program whose .s is an OVERSIZE stub (name.s.OVERSIZE, no .s) is listed too (R-1855; the cto's zsm ruling 2026-10-31); its figures are read from the stub by the census readers.
#   util_spine_population.sh [--corpus DIR] [--lang L]      (default corpus: the sibling of this harness)
# rc 0 listed · rc 2 no corpus.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_paths.sh"; C="$S4E_CORPUS"; L=""
while [ $# -gt 0 ]; do case "$1" in --corpus) C="$2"; shift 2;; --lang) L="$2"; shift 2;; *) echo "usage: util_spine_population.sh [--corpus DIR] [--lang L]" >&2; exit 2;; esac; done
[ -d "$C/benchmarks" ] && [ -d "$C/demos" ] || { echo "REFUSE(2): no corpus at $C" >&2; exit 2; }
C="$(cd "$C" && pwd)"
{ find "$C/benchmarks" "$C/demos" \( -name '*.s' -o -name '*.s.OVERSIZE' \) | while read -r f; do s="${f%.OVERSIZE}"; printf '%s\n' "${s%.s}"; done | sort -u | while read -r s; do
      for e in sno icn pl; do [ -f "$s.$e" ] && case "$e" in sno) printf 'snobol4\t%s\n' "$s.$e";; icn) printf 'icon\t%s\n' "$s.$e";; pl) printf 'prolog\t%s\n' "$s.$e";; esac; done; done
  for e in pas raku sc reb; do find "$C/demos" "$C/benchmarks" -name "*.$e" | sort | while read -r f; do
      case "$e" in pas) printf 'pascal\t%s\n' "$f";; raku) printf 'raku\t%s\n' "$f";; sc) printf 'snocone\t%s\n' "$f";; reb) printf 'rebus\t%s\n' "$f";; esac; done; done
} | { if [ -n "$L" ]; then awk -F'\t' -v l="$L" '$1 == l'; else cat; fi; }
