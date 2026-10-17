#!/usr/bin/env bash
# util_cut_icon_kernel_refs.sh -- CUT A RUN REF FROM THE ARIZONA ORACLE FOR EVERY ICON KERNEL AND DEMO,
# per THE KERNEL CONVENTION (RULES.md § FACT RULE, Lon 2026-09-11 16:3x CDT, CEO-567) and the ceo's
# CEO-609 ruling that a kernel or demo WITHOUT a ref is owed A REF -- cut from iconx and recorded --
# never absorption into the rungs (CEO-565 forbids a second copy; benchmarks/ and demos/ are the only
# trees carrying .s artifacts and the SPEED axis, and a rung suite file is a CONTAINER).
#
#   bash ../harness/scripts/util_cut_icon_kernel_refs.sh                 # CENSUS ONLY: classify, write nothing
#   bash ../harness/scripts/util_cut_icon_kernel_refs.sh --apply          # mint NAME.ref beside every LIVE kernel
#   bash ../harness/scripts/util_cut_icon_kernel_refs.sh --root demos/icon
#   bash ../harness/scripts/util_cut_icon_kernel_refs.sh --only queens --only micro
#   bash ../harness/scripts/util_cut_icon_kernel_refs.sh --tsv out.tsv    # the census as a machine-readable row set
#
# ⛔⭐⭐ WHY THIS IS NOT util_cut_icon_ipl_refs.sh WITH A --dir, AND WHY THAT IS NOT A FORK (hq_V
# 2026-09-12). That script is the same TAXONOMY and a DIFFERENT ISOLATION CONTRACT, and only the second
# half is what binds it to its tree: it builds one template from the six IPL subdirectories
# (progs/gprogs/procs/gprocs/incl/gincl), takes `--dir` as ONE package-relative subdirectory name and
# REFUSES a path with a slash, walks that one directory FLAT (`ls -1 *.icn`), and reads its rulings from
# $PKG/UNGRADABLE.tsv. Every one of those is correct for a vendored flat package and wrong here:
# benchmarks/icon has three subdirectories (rate/, rtx/, shootout/), its link modules sit BESIDE the
# programs that link them rather than in a procs/ library, and demos/icon/jcon links UPWARD out of its
# own tree into ../../../packages/icon/jcon-compiler/. ⭐ What IS shared is shared BY SOURCING, never by
# restating: lib_icn_rundir.sh (THE ONE AUTHORITY for the run-directory contract -- stdin, argv,
# NAME.fixtures/, env) and lib_oracle_flags.sh (THE ONE authority on oracle selection). The eight
# outcome names below are deliberately spelled the same as that script's so one reader can read both
# censuses; if either taxonomy ever grows a class, the other is owed the same class.
#
# ⛔⛔ EVERY RUN IS SANDBOXED IN A DISPOSABLE COPY, NEVER THE TRACKED TREE -- the same hazard that renamed
# 275 vendored IPL sources to UPPERCASE in place when its cutter first used the real directory as cwd.
# The kernel trees carry the identical shape: geddump/tgrlink/ipxref open files named on argv or read
# their own neighbourhood, and `icont` itself writes NAME.u1/NAME.x beside the source it is handed.
# ⭐ THE TEMPLATE EXCLUDES *.s: the two trees are 18M+9.4M with the .s artifacts and 1.2M without them,
# and nothing in a run reads an artifact. A per-run copy is then cheap enough to be unconditional, which
# is the only way an isolation rule survives contact with a 51-file walk.
#
# ⛔⭐ THE TEMPLATE IS PRE-TRANSLATED ONCE, BECAUSE `link` IS RESOLVED AT LINK TIME AGAINST NAME.u1 AND
# NOTHING IN THE CORPUS SHIPS ONE (doc/files.htm + man/man1/icont.1: `link X` resolves to `X.u1`, cwd
# first then $IPATH; `icont -c a.icn` stops after translation and leaves a.u1 behind, and "a directory of
# such files functions as a linkable library"). Six benchmarks link options/post/shuffle and four jcon
# demos link seventeen modules under packages/icon/jcon-compiler, so a cutter that skips this step
# reports ORACLE_FAIL on ten programs and calls it a defect of the corpus.
#
# ⛔ A .ref MINTED FROM A RUN THAT IS NOT A GENUINE CLEAN EXECUTION PINS A LIE, so every walked file gets
# exactly ONE NAMED outcome and never a silent skip:
#   MODULE         -- no `procedure main` and no `link` that could supply one. A library module is not a
#                     kernel, is never run alone, and is NEVER owed a ref (options/post/shuffle).
#   HAS_REF        -- a NAME.ref already sits beside it. Owes nothing (CEO-609).
#   WRAPPER_IN_KERNEL / TIMING_IN_KERNEL -- CEO-567 CLAUSE 1 UNMET, in its two shapes. WRAPPER_IN_KERNEL:
#                     the source links `post` or calls Init__/Term__ -- the 1993 Icon benchmarking
#                     wrapper is LINKED INTO the kernel and prints the oracle's version string, the
#                     HOSTNAME, &features, elapsed time and storage/collection counts TO STDOUT, mixed
#                     with the program's own output -- and reassigns `write`/`writes` to suppress that
#                     output entirely unless $OUTPUT is set. That is exactly the defect CEO-567 outlawed
#                     (clauses 1 and 2), and while it stands clause 3 is UNREACHABLE: a ref cut from
#                     that stream pins implementation identity no other engine can reproduce. Named as
#                     OWED with its cause, never minted. TIMING_IN_KERNEL: the source calls a timing
#                     builtin (&time/&clock/&now) ITSELF and writes the reading to stdout -- the same
#                     defect SCRIP-authored rather than inherited, and RULES.md's enforcement clause names
#                     it in those words ("no source in it calls a timing or iteration builtin").
#                     ⛔ BOTH are keyed on the DECLARATION (the link, the calls), never on the shape of the
#                     bytes, so a cured kernel leaves the class by being cured and not by a pattern moving.
#                     ⭐⭐ AND THE STRUCTURAL CHECK WAS ADDED ONLY AFTER THE RUN-TWICE ARM FOUND THE SAME
#                     FILES EMPIRICALLY: the first census of these trees reported the fourteen &time
#                     kernels as NONDETERMINISTIC, which is TRUE and is the canary. The structural class
#                     replaces a symptom with its cause; it does not replace the canary, and the
#                     NONDETERMINISTIC arm below is deliberately left intact so that deleting this check
#                     degrades the report rather than silencing it.
#   EMPTY          -- rc=0 and zero bytes of stdout. A 0-byte ref grades "produced nothing" as correct.
#   ORACLE_FAIL    -- rc!=0 and no named class below explains it. The row carries THE ORACLE'S OWN FIRST
#                     NON-BLANK LINE as its reason, never a sentence this script composed.
#   TIMEOUT        -- exceeded $TIMEOUT (an interactive read, or a genuinely long run).
#   UNDECLARED_IDENTIFIER -- an identifier never resolved at link time, checked at ANY rc: this oracle is
#                     built without graphics, so a program reaching a missing name may warn and stop
#                     (rc=0) or die calling through it (error 106).
#   OVERSIZED      -- stdout exceeds $MAX_BYTES, checked with `wc -c` ON THE FILE before it is ever
#                     slurped into a shell variable (a program that is not quiet while it times out can
#                     print gigabytes before `timeout` kills it).
#   SUSPECT_USAGE  -- rc=0, non-empty, and the first line reads like a usage/error banner printed on a
#                     clean exit. A program that prints "usage: prog file" and exits 0 would otherwise
#                     pin its own complaint as ground truth. Named for a human to eyeball, never LIVE.
#   NONDETERMINISTIC -- run TWICE in independent fresh rundirs; the two stdouts disagree. Pinning either
#                     would fail the other forever. ⭐ This is the arm that catches benchmarks/icon/rate/*
#                     by construction: those nine are the WRAPPED form, not a kernel -- they read &time
#                     inside the program and write "<units> <elapsed_ms> <checksum>", so two of the three
#                     fields are machine-dependent by design. Their own headers say the CHECKSUM is the
#                     cross-engine correctness datum; extracting one field from a run is a MASK, this
#                     script does not invent one, and the row says so.
#   IMPLEMENTATION_IDENTITY -- a clean, stable, non-empty run whose OUTPUT contains the oracle's own version
#                     string or the host name. Pinning it makes the one oracle the correct answer. Wants a
#                     mask or an outside-baseline ruling, never a byte ref. See the long note at
#                     IDENT_PATTERNS for the measurement and for why the test is on the output.
#   LIVE           -- rc=0 both runs, non-empty, byte-identical across the two, no usage banner, no
#                     undeclared identifier. Minted as NAME.ref with --apply; otherwise "would mint".
#
# ⛔⭐ A KERNEL ALREADY RULED UNGRADABLE IS NEVER A MINT CANDIDATE. This script walks the TREE and a
# ruling lives in a FILE BESIDE the tree, so without reading it the next --apply SILENTLY UN-RULES a
# decision a human made, with no diff to show it was overturned. Each root may carry UNGRADABLE.tsv
# whose first tab-separated column is the root-relative path of a kernel a ref is the wrong instrument
# for; those rows are reported RULED_UNGRADABLE and skipped at mint time whatever the run says.
#
# ⛔ THE SHOOTOUT FIVE ARE SKIPPED BY DEFAULT AND THE SKIP IS PRINTED, NEVER SILENT (CEO-609: "The
# shootout five stay the cfo's row and become kernel-with-ref when it lands; the census counts them until
# then and that is honest"). --no-skip-shootout walks them anyway for whoever holds that row.
#
# rc=0 nothing owed and uncut · rc=1 naming what is still owed · rc=2 the instrument cannot measure.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
C="$S4E/corpus"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ REFUSES(2): lib_oracle_flags.sh unloadable -- the ONE oracle-flag authority" >&2; exit 2; }
. "$HERE/lib_icn_rundir.sh"   2>/dev/null || { echo "⛔ REFUSES(2): lib_icn_rundir.sh unloadable -- THE ONE AUTHORITY for the run-directory contract" >&2; exit 2; }
TIMEOUT="${TIMEOUT:-20}"; MAX_BYTES="${MAX_BYTES:-1048576}"
APPLY=0; VERBOSE=0; SKIP_SHOOTOUT=1; TSV=""
declare -a ROOTS=() ONLY=()
while [ $# -gt 0 ]; do case "$1" in
  --apply) APPLY=1 ;;
  -v|--verbose) VERBOSE=1 ;;
  --no-skip-shootout) SKIP_SHOOTOUT=0 ;;
  --root) shift; [ $# -gt 0 ] || { echo "⛔ --root needs a value" >&2; exit 2; }; ROOTS+=("${1%/}") ;;
  --root=*) ROOTS+=("${1#--root=}") ;;
  --only) shift; [ $# -gt 0 ] || { echo "⛔ --only needs a value" >&2; exit 2; }; ONLY+=("${1%.icn}") ;;
  --only=*) ONLY+=("${1#--only=}"); ONLY[-1]="${ONLY[-1]%.icn}" ;;
  --tsv) shift; [ $# -gt 0 ] || { echo "⛔ --tsv needs a value" >&2; exit 2; }; TSV="$1" ;;
  *) echo "usage: $0 [--apply] [-v] [--root <corpus-relative tree>]... [--only NAME]... [--no-skip-shootout] [--tsv FILE]" >&2; exit 2 ;;
esac; shift; done
[ "${#ROOTS[@]}" -gt 0 ] || ROOTS=(benchmarks/icon demos/icon)
for r in "${ROOTS[@]}"; do
  case "$r" in /*|*..*) echo "⛔ REFUSES(2): --root takes a corpus-relative tree, got '$r'" >&2; exit 2 ;; esac
  [ -d "$C/$r" ] || { echo "⛔ REFUSES(2): corpus subtree missing: $C/$r" >&2; exit 2; }
done
ICONT="$(icont_bin)" || exit 2
ICONX="$(iconx_bin)" || exit 2
# ⛔ THE ORACLE'S OWN IDENTITY GOES IN THE REPORT. A census that does not say which build it measured is a
# census nobody can re-run: the .std sidecars in benchmarks/icon were cut from "Icon Interpreter Version
# 8.10. March 11, 1993" and this oracle prints 9.5.25a, which is the whole reason five of them pin nothing.
ORACLE_ID="$("$ICONX" -V 2>&1 | head -1)"
# ⛔⭐⭐ THE IDENTITY PATTERNS A REF MAY NEVER CONTAIN, AND WHY THE TEST IS EMPIRICAL AND NOT STRUCTURAL
# (hq_V 2026-09-12, caught by scanning the eighteen refs this script had just minted -- which is the only
# reason it was caught). benchmarks/icon/version.icn is four lines whose whole body is `write(&version)`, so
# its run is a CLEAN, DETERMINISTIC, non-empty, banner-free success and every arm below passed it: the ref
# minted was the single line "Icon Version 9.5.25a, September 7, 2025". That pins THE ORACLE'S OWN IDENTITY
# as the correct answer -- SCRIP prints its own version and can never match it, and the pin moves the day the
# oracle is rebuilt. ⛔ THE SAME CLASS IS ALREADY ON THE RECORD IN THE ICON RUNGS: procedure_every_alt_
# replace_4 is a keyword dump whose diff is entirely `&version: Jcon 2.2` vs `Icon 9.5`, `&allocated`,
# `&regions`, `&storage` and `&progname`, and it needs a mask or an outside-baseline ruling rather than a
# re-cut (GOAL-HQ-VALIDATE HQV-18). A cutter aimed at a NEW tree inherits that blindness unless told, and
# this one did.
# ⛔ THE TEST IS ON THE OUTPUT, NOT ON THE SOURCE, because the structural version over-refuses and the
# over-refusal is not cheap: benchmarks/icon/tgrlink.icn mentions &progname SEVEN times -- every one of them
# inside a `stop(...)` error path that a successful run never takes -- and its 256 KB ref is clean, measured
# (zero hits). Refusing it on the grep would have withheld a good ref from a 256 KB deterministic program on
# the strength of dead code. So: mention in the source is nothing, presence in the OUTPUT is disqualifying.
declare -a IDENT_PATTERNS=()
_iv="$(printf '%s' "$ORACLE_ID" | grep -oE '[Ii]con Version [0-9][0-9A-Za-z.]*' | head -1)"
[ -n "$_iv" ] && IDENT_PATTERNS+=("$_iv")
_ih="$(uname -n 2>/dev/null)"
[ -n "$_ih" ] && IDENT_PATTERNS+=("$_ih")
[ "${#IDENT_PATTERNS[@]}" -gt 0 ] || { echo "⛔ REFUSES(2): could not derive a single implementation-identity pattern from the oracle ($ORACLE_ID) or the host -- an instrument that cannot recognise a self-pin must not mint refs" >&2; exit 2; }

# ── ONE pristine template, built once; every oracle invocation gets its OWN disposable copy of it.
TEMPLATE="$(mktemp -d "${TMPDIR:-/tmp}/icn_kernel_ref_template.XXXXXX")" || { echo "⛔ mktemp failed" >&2; exit 2; }
trap 'rm -rf "$TEMPLATE"' EXIT
declare -a STAGE=("${ROOTS[@]}")
# demos/icon/jcon/*.icn link "../../../packages/icon/jcon-compiler/<mod>", escaping their own tree, so the
# template must hold that subtree at its real corpus-relative position or those four rows read ORACLE_FAIL
# on a missing module rather than on anything the program does.
[ -d "$C/packages/icon/jcon-compiler" ] && STAGE+=(packages/icon/jcon-compiler)
for r in "${STAGE[@]}"; do
  mkdir -p "$TEMPLATE/$(dirname "$r")"
  ( cd "$C" && tar cf - --exclude='*.s' "$r" ) | ( cd "$TEMPLATE" && tar xf - ) || { echo "⛔ REFUSES(2): could not stage $r into the template" >&2; exit 2; }
done
# Pre-translate every .icn in the template so `link` resolves. Best-effort by design: a module that will
# not translate is a finding about the program that links it, reported there, not a reason to stop here.
while IFS= read -r m; do
  ( cd "$(dirname "$TEMPLATE/$m")" && timeout -k 5 "$TIMEOUT" "$ICONT" -s -u -c "$(basename "$m")" >/dev/null 2>&1 )
done < <(cd "$TEMPLATE" && find . -name '*.icn' | sed 's|^\./||' | sort)

# run_once <root-relative icn> <root> <outfile> -> combined stdout+stderr of ONE isolated run; rc via return.
run_once() {
  local rel="$1" root="$2" outfile="$3" work rc icn d b stdin_src crc
  icn="$C/$root/$rel"; b="$(basename "${rel%.icn}")"; d="$(dirname "$rel")"
  work="$(mktemp -d "${TMPDIR:-/tmp}/icn_kernel_ref_run.XXXXXX")" || return 127
  cp -r "$TEMPLATE"/. "$work"/ || { rm -rf "$work"; return 127; }
  local -a argv=() envv=()
  icn_rundir_argv "$icn" argv; [ $? -eq 2 ] && { rm -rf "$work"; return 126; }
  icn_rundir_env  "$icn" envv; [ $? -eq 2 ] && { rm -rf "$work"; return 126; }
  ipl_fixtures_stage "$icn" "$work/$root/$d"; [ $? -eq 2 ] && { rm -rf "$work"; return 125; }
  # ⛔ TWO SPELLINGS OF ONE SIDECAR, READ IN A STATED ORDER AND NEITHER INVENTED HERE. lib_icn_rundir.sh's
  # icn_rundir_stdin is THE authority (NAME.stdin beside the source, else config/NAME.stdin). NAME.dat is
  # the PRE-EXISTING benchmarks-tree spelling -- concord.dat/ipxref.dat/rsg.dat arrive from upstream
  # icon-master/tests/bench and ReRun-icont feeds them on stdin there, and util_cut_icon_ipl_refs.sh reads
  # the same .dat name for the same reason. It is consulted ONLY when the authority found nothing, so this
  # script can never disagree with the contract; it is named here rather than quietly normalised because a
  # third spelling is how the two-instruments-one-question defect gets in.
  stdin_src="$(icn_rundir_stdin "$icn")"
  [ "$stdin_src" = /dev/null ] && [ -f "${icn%.icn}.dat" ] && stdin_src="${icn%.icn}.dat"
  : > "$outfile.link"
  ( cd "$work/$root/$d" && timeout -k 5 "$TIMEOUT" env ${envv[@]+"${envv[@]}"} "$ICONT" -s -u -o "$b.x" "$b.icn" > "$outfile.link" 2>&1 )
  crc=$?
  if [ ! -f "$work/$root/$d/$b.x" ]; then
    cp "$outfile.link" "$outfile"; rm -rf "$work"; [ "$crc" -eq 0 ] && crc=1; return "$crc"
  fi
  ( cd "$work/$root/$d" && timeout -k 5 "$TIMEOUT" env ${envv[@]+"${envv[@]}"} "$ICONX" "$b.x" ${argv[@]+"${argv[@]}"} < "$stdin_src" > "$outfile" 2>&1 )
  rc=$?
  rm -rf "$work"
  return "$rc"
}
# first_diag <file> -> the first NON-BLANK line, printable-ASCII only, truncated. NOT `head -1`: icont opens
# with a blank line before "Run-time error N", so head -1 reports an EMPTY reason for every runtime error.
first_diag() {
  local _l _p _n; _l="$(grep -m1 -v '^[[:space:]]*$' "$1" 2>/dev/null)"
  _n="$(printf '%s' "$_l" | LC_ALL=C wc -c | tr -d ' ')"
  _p="$(printf '%s' "$_l" | LC_ALL=C tr '\t' ' ' | LC_ALL=C tr -cd '\40-\176' | sed 's/^ *//; s/ *$//')"
  [ -n "$_p" ] || { printf '<non-textual: %s bytes on the first non-blank line, no printable ASCII>' "$_n"; return 0; }
  printf '%s' "$_p" | cut -c1-200
}
W="$(mktemp -d "${TMPDIR:-/tmp}/icn_kernel_ref_out.XXXXXX")" || exit 2
trap 'rm -rf "$TEMPLATE" "$W"' EXIT
declare -A COUNT=()
MINTED=0; OWED=0; TOTAL=0
[ -n "$TSV" ] && printf 'tree\tprogram\toutcome\tbytes\treason\n' > "$TSV"
row() { # <root> <rel> <outcome> <bytes> <reason>
  COUNT["$3"]=$(( ${COUNT["$3"]:-0} + 1 )); TOTAL=$((TOTAL+1))
  printf '%-14s %-44s %-21s %8s  %s\n' "$1" "$2" "$3" "$4" "$5"
  [ -n "$TSV" ] && printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" >> "$TSV"
  case "$3" in HAS_REF|MODULE|LIVE) ;; *) OWED=$((OWED+1)) ;; esac
}
echo "ICON KERNEL REF CENSUS -- oracle: $ORACLE_ID"
echo "roots: ${ROOTS[*]}   mode: $([ "$APPLY" -eq 1 ] && echo APPLY || echo 'CENSUS (writes nothing)')   timeout=${TIMEOUT}s max=${MAX_BYTES}B"
[ "$SKIP_SHOOTOUT" -eq 1 ] && echo "⛔ SKIPPING shootout/ -- the shootout five are the cfo's row (CEO-609); --no-skip-shootout to walk them."
printf '%-14s %-44s %-21s %8s  %s\n' tree program outcome bytes reason
for root in "${ROOTS[@]}"; do
  UNG="$C/$root/UNGRADABLE.tsv"
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    [ "$SKIP_SHOOTOUT" -eq 1 ] && case "$rel" in shootout/*) continue ;; esac
    b="$(basename "${rel%.icn}")"
    if [ "${#ONLY[@]}" -gt 0 ]; then
      hit=0; for w in "${ONLY[@]}"; do [ "$w" = "$b" ] && hit=1; done; [ "$hit" -eq 1 ] || continue
    fi
    icn="$C/$root/$rel"
    if [ -f "$UNG" ] && awk -F'\t' -v w="$rel" '$1==w{f=1} END{exit !f}' "$UNG"; then
      row "$root" "$rel" RULED_UNGRADABLE - "ruled in $root/UNGRADABLE.tsv -- a ref is the wrong instrument for it"; continue
    fi
    if [ -f "${icn%.icn}.ref" ]; then
      row "$root" "$rel" HAS_REF "$(wc -c <"${icn%.icn}.ref" | tr -d ' ')" "owes nothing (CEO-609)"; continue
    fi
    has_main=0; grep -qE '^[[:space:]]*procedure[[:space:]]+main[[:space:]]*\(' "$icn" && has_main=1
    has_link=0; grep -qE '^[[:space:]]*link[[:space:]]' "$icn" && has_link=1
    if [ "$has_main" -eq 0 ] && [ "$has_link" -eq 0 ]; then
      row "$root" "$rel" MODULE - "no procedure main and no link -- a library module is never a kernel"; continue
    fi
    # ⛔ KEYED ON THE DECLARATION: the source links the 1993 wrapper, or calls its entry points. Structural,
    # so a kernel made pristine leaves this class by being cured and not by a byte pattern changing.
    if grep -qE '^[[:space:]]*link[[:space:]].*\bpost\b' "$icn" || grep -qE '\b(Init__|Term__)[[:space:]]*\(' "$icn"; then
      why="links post / calls Init__-Term__: the 1993 benchmark wrapper is IN the kernel and writes the oracle version, hostname, &features, elapsed time and storage counts to STDOUT (CEO-567 clauses 1-2 unmet, so clause 3 is unreachable)"
      sd=""; [ -f "${icn%.icn}.std" ] && sd=" -- the NAME.std beside it is upstream's own Icon 8.10 self-benchmark dump, not this program's output"
      row "$root" "$rel" WRAPPER_IN_KERNEL - "$why$sd"; continue
    fi
    # ⛔⭐ THE ORACLE DOES NOT HAVE THE LANGUAGE, WHICH IS NOT A DEFECT OF THE PROGRAM (hq_V 2026-09-12).
    # `$import` is a SCRIP polyglot preprocessor directive, not Icon: demos/icon/demo/family_icon.icn and its
    # family_net twin declare `$import family_prolog.query_count` to call INTO the Prolog block of the same
    # demo, and Arizona icont answers `# "import": invalid preprocessing directive` and stops at that line.
    # Reported as ORACLE_FAIL these two read as broken Icon; they are a polyglot component the one oracle
    # cannot compile BY CONSTRUCTION, so an oracle-cut ref is impossible rather than merely missing -- and
    # "THE ORACLE MINTS, SCRIP IS GRADED, never the reverse" forbids the obvious shortcut of pinning our own
    # output instead. Same category as tests/scrip_test/polyglot_tri_lib.icn. Named for a ruling, not minted.
    if grep -qE '^[[:space:]]*\$import[[:space:]]' "$icn"; then
      row "$root" "$rel" POLYGLOT_EXTENSION - "declares \$import (a SCRIP polyglot directive Icon has no form for): the one oracle refuses at that line, so an oracle-cut ref is impossible by construction, not missing"; continue
    fi
    # ⛔ THE SAME CLAUSE, SCRIP-AUTHORED: the kernel reads the clock itself and writes the reading to stdout.
    # MEASURED (hq_V 2026-09-12): benchmarks/icon/rate/* write "<units> <elapsed_ms> <checksum>" and
    # benchmarks/icon/rtx/* write "ms: <&time delta>" -- two of three fields, and one of two lines, are
    # machine-dependent by construction. benchmarks/icon/micro.icn is the same shape at suite scale and is
    # why it read TIMEOUT at 20s: it is a self-timing micro-benchmark suite, not a program with an answer.
    # ⛔ ON CODE, NEVER ON COMMENTS (hq_icon 2026-09-23): a kernel whose header EXPLAINS that its timing moved to the
    # generated wrapper names &time in prose and was refused as TIMING_IN_KERNEL. Icon comments run from # to end of line.
    if sed 's/#.*//' "$icn" | grep -qE '&time|&clock|&now'; then
      row "$root" "$rel" TIMING_IN_KERNEL - "the kernel calls a timing builtin (&time/&clock/&now) and writes the reading to stdout -- CEO-567 clause 1 unmet (RULES.md: 'no source in it calls a timing or iteration builtin'), so clause 3 is unreachable until the wrapping is generated around a pristine kernel instead"; continue
    fi
    o1="$W/$b.1"; o2="$W/$b.2"
    run_once "$rel" "$root" "$o1"; rc1=$?
    case "$rc1" in
      124) row "$root" "$rel" TIMEOUT - "exceeded ${TIMEOUT}s"; continue ;;
      126) row "$root" "$rel" MALFORMED_SIDECAR - "an argv or env sidecar refused -- refusing to guess what the program was given"; continue ;;
      125) row "$root" "$rel" MALFORMED_SIDECAR - "NAME.fixtures/ would not stage"; continue ;;
      127) row "$root" "$rel" INSTRUMENT_FAIL - "could not build a rundir"; continue ;;
    esac
    # ⛔⭐ AN UNDECLARED IDENTIFIER DISQUALIFIES A RUN ONLY WHEN IT EXPLAINS A FAILURE (hq_V 2026-09-12,
    # measured, correcting this script's own first draft). util_cut_icon_ipl_refs.sh checks this at ANY rc
    # and is RIGHT to: in that package the cause is a graphics builtin the oracle was not built with, and
    # the program calls through the missing name and dies (error 106). Here the cause can be an ordinary
    # missing `local`, which Icon resolves as a global and `-u` merely WARNS about. MEASURED on
    # demos/icon/demo/icon_parser.icn ("nl": undeclared identifier, procedure p_global): translated and run
    # BOTH WAYS, `icont -s -u` and `icont -s`, the executable links in both and the two runs are
    # BYTE-IDENTICAL -- so the warning never touched the answer, and reporting it as the outcome denied a
    # perfectly good program a ref on the strength of a diagnostic about nothing. ⭐ The evidence is NOT
    # thrown away: it still preempts when the run also failed or produced nothing, which is every case
    # where it could actually be the cause, and the reason column still carries the oracle's own words.
    # ⛔ MATCH ICONT'S OWN SHAPE, `"name": undeclared identifier` (hq_icon 2026-09-23): a bare substring matched a PROGRAM'S
    # OUTPUT -- benchmarks/icon/concord builds a concordance of icont's man page, whose -u entry reads 'undeclared identifiers',
    # and the cutter refused a clean 61565-byte run as a diagnostic. The quote-colon prefix is the warning's, never prose's.
    if grep -q '": undeclared identifier' "$o1" 2>/dev/null || grep -q '": undeclared identifier' "$o1.link" 2>/dev/null; then
      # ⛔ THE DISCRIMINATOR IS WHICH STREAM CARRIES IT, and it is the one thing that separates a cause from
      # a comment. In the RUN stream at any rc it IS the failure (Icon error 106, calling through a name that
      # never resolved). In the LINK stream with rc=0 it is icont warning about a resolution it went on to
      # make anyway. Keying on "rc!=0 OR empty output" instead -- which this script did for one draft --
      # relabelled demos/icon/demo/icon_parser.icn, whose real outcome is EMPTY because it is a parser handed
      # /dev/null, as a diagnostic about an identifier that provably changed nothing.
      if grep -q '": undeclared identifier' "$o1" 2>/dev/null || [ "$rc1" -ne 0 ]; then
        row "$root" "$rel" UNDECLARED_IDENTIFIER - "$(first_diag "$o1.link")"; continue
      fi
      [ "$VERBOSE" -eq 1 ] && echo "   note: $rel links with an undeclared identifier that did not affect the run: $(first_diag "$o1.link")"
    fi
    if [ "$rc1" -ne 0 ]; then
      row "$root" "$rel" ORACLE_FAIL - "rc=$rc1: $(first_diag "$o1")"; continue
    fi
    n1="$(wc -c <"$o1" | tr -d ' ')"
    [ "$n1" -eq 0 ] && { row "$root" "$rel" EMPTY 0 "rc=0 and zero bytes -- a 0-byte ref grades 'produced nothing' as correct"; continue; }
    [ "$n1" -gt "$MAX_BYTES" ] && { row "$root" "$rel" OVERSIZED "$n1" "exceeds MAX_BYTES=$MAX_BYTES"; continue; }
    if grep -qiE '^[[:space:]]*(usage:|can.t open|error:)' <(head -1 "$o1"); then
      row "$root" "$rel" SUSPECT_USAGE "$n1" "rc=0 but the first line is a usage/error banner: $(first_diag "$o1")"; continue
    fi
    run_once "$rel" "$root" "$o2"; rc2=$?
    if [ "$rc2" -ne "$rc1" ] || ! cmp -s "$o1" "$o2"; then
      row "$root" "$rel" NONDETERMINISTIC "$n1" "two independent runs disagree (rc $rc1 vs $rc2) -- pinning either would fail the other forever"; continue
    fi
    _hit=""
    for _pat in "${IDENT_PATTERNS[@]}"; do
      if LC_ALL=C grep -qF "$_pat" "$o1" 2>/dev/null; then _hit="$_pat"; break; fi
    done
    if [ -n "$_hit" ]; then
      row "$root" "$rel" IMPLEMENTATION_IDENTITY "$n1" "the output carries the oracle's own identity ('$_hit'): a byte pin would make the ONE oracle the correct answer, which no other engine can reproduce and which moves when the oracle is rebuilt -- wants a mask or an outside-baseline ruling, never a re-cut (same class as the rungs' procedure_every_alt_replace_4)"; continue
    fi
    if [ "$APPLY" -eq 1 ]; then
      cp "$o1" "${icn%.icn}.ref" || { row "$root" "$rel" INSTRUMENT_FAIL - "could not write ${rel%.icn}.ref"; continue; }
      MINTED=$((MINTED+1)); row "$root" "$rel" LIVE "$n1" "minted ${rel%.icn}.ref from $ORACLE_ID"
    else
      row "$root" "$rel" LIVE "$n1" "would mint ${rel%.icn}.ref (stable across two independent runs)"
    fi
  done < <(cd "$C/$root" && find . -name '*.icn' | sed 's|^\./||' | sort)
done
echo "---"
for k in $(printf '%s\n' "${!COUNT[@]}" | sort); do printf '  %-21s %d\n' "$k" "${COUNT[$k]}"; done
printf 'ICON_KERNEL_REF_CENSUS: total=%d owed=%d minted=%d roots=%s oracle=%s\n' "$TOTAL" "$OWED" "$MINTED" "${ROOTS[*]}" "$ORACLE_ID"
[ "$OWED" -eq 0 ] && exit 0
exit 1
