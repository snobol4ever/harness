# lib_ipl_sidecar_gate.sh -- the shared body of the IPL run-sidecar gates (hq_icon 2026-09-27; Lon's word "Get IPL to 843.";
# ceo CEO-1315: "one gate per sidecar proving red once and green once"). A gate plants ONE unit and its sidecar in a scratch
# IPL-shaped package, then drives it through the REAL cutter (util_cut_icon_ipl_refs.sh, S4E_HOME pointed at the scratch home)
# and through ipl_isolation_run -- the function test_icon_ipl_suite.sh grades with -- in m3 and m4, exactly as the runner calls
# it (argv after --, the NAME.rc status graded when declared). GREEN: run it against the scripts beside this file. RED: run it
# against a scratch copy whose one reader is doctored back to the origin behaviour (sg_doctor), and the gate must read the loss.
#   . lib_ipl_sidecar_gate.sh; sg_init
#   (plant $SG_PKG/progs/NAME.icn and its sidecar)
#   sg_verdict "$SG_HERE" NAME PLANT  -> prints "MINTED=0|1 M3=PASS|FAIL M4=PASS|FAIL REF=<bytes>"; sg_ref "$SG_HERE" NAME is its ref
#   d="$(sg_doctor 'python replacement code')"; sg_verdict "$d" NAME
SG_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sg_init() {
  SG_T="$(mktemp -d "${TMPDIR:-/tmp}/ipl_sidecar_gate.XXXXXX")" || { echo "⛔ GATE REFUSE(2): mktemp failed"; exit 2; }
  trap 'rm -rf "$SG_T"' EXIT
  SG_SCRIP="$SG_HERE/../../SCRIP/scrip"; SG_OUT="$SG_HERE/../../SCRIP/out"
  [ -x "$SG_SCRIP" ] || { echo "⛔ GATE REFUSE(2): scrip not built"; exit 2; }
  ( . "$SG_HERE/lib_oracle_flags.sh" && [ -x "$(icont_bin)" ] ) || { echo "⛔ GATE REFUSE(2): the Icon oracle is required (icont_bin in lib_oracle_flags.sh)"; exit 2; }
}
# sg_fresh_pkg -- a new empty scratch home for one verdict (a doctored run never sees the green run's ref)
sg_fresh_pkg() {
  SG_H="$SG_T/home.$1"; rm -rf "$SG_H"; SG_PKG="$SG_H/corpus/packages/icon/ipl"
  mkdir -p "$SG_PKG"/progs "$SG_PKG"/procs "$SG_PKG"/gprocs "$SG_PKG"/incl "$SG_PKG"/gincl
}
# sg_doctor <python-code-editing-variable-s> [file] -- a copy of the four files with one edit applied to lib_icon_ipl_isolation.sh
# (or to the named file); echoes the copy's directory
sg_doctor() {
  local code="$1" file="${2:-lib_icon_ipl_isolation.sh}" d="$SG_T/doctored.$RANDOM"
  mkdir -p "$d"; cp "$SG_HERE"/util_cut_icon_ipl_refs.sh "$SG_HERE"/lib_oracle_flags.sh "$SG_HERE"/lib_icon_ipl_isolation.sh "$SG_HERE"/ipl_pin_shim.c "$SG_HERE"/test_icon_ipl_suite.sh "$d"/
  cp "$SG_HERE"/util_apply_ceo409_mask.py "$SG_HERE"/corpus_suite_harness.py "$SG_HERE"/util_render_error_voice.py "$d"/
  python3 - "$d/$file" "$code" <<'PY' || { echo "⛔ GATE REFUSE(2): the doctoring edit did not apply" >&2; return 2; }
import sys
p, code = sys.argv[1], sys.argv[2]
s = open(p).read(); before = s
exec(code)
if s == before: sys.exit(1)
open(p, 'w').write(s)
PY
  echo "$d"
}
# sg_ref <scriptsdir> <name> -- the path of the ref the last sg_verdict over that scripts dir cut (sg_verdict runs in $(...))
sg_ref() { echo "$SG_T/home.$(basename "$1")/corpus/packages/icon/ipl/progs/$2.ref"; }
# sg_verdict <scriptsdir> <name> <plant-function> -- plants into a fresh package, cuts with that scripts dir's cutter, grades both modes
sg_verdict() {
  local sd="$1" n="$2" plant="$3" tag minted=0 v3=FAIL v4=FAIL rc3 rc4 want=""
  tag="$(basename "$sd")"; sg_fresh_pkg "$tag"; "$plant"
  S4E_HOME="$SG_H" timeout -k 5 300 bash "$sd/util_cut_icon_ipl_refs.sh" --apply --only "$n" > "$SG_T/cut.$tag.log" 2>&1
  SG_REF="$SG_PKG/progs/$n.ref"; [ -f "$SG_REF" ] && minted=1
  want="$( . "$sd/lib_icon_ipl_isolation.sh"; ipl_rc_declared "$SG_PKG/progs/$n.icn" )" || want=MALFORMED
  if [ "$minted" -eq 1 ]; then
    local out3="$SG_T/$n.$tag.m3" out4="$SG_T/$n.$tag.m4" bin="$SG_T/$n.$tag.bin" stdin=/dev/null ca
    # ⛔ THE UNIT'S COMPILE SWITCHES ARE THE PACKAGE'S OWN DECLARATION, READ AS THE RUNNER READS THEM (clause 8 (f), CEO-1281; the coo's
    # batch audit 2026-09-27): the scratch package carries the real IPL ALL.csv's header and its first row re-keyed to this fixture, and
    # the cell comes back through declared_memory_table + declared_compile_args_from_table -- this lib types no switch of its own.
    awk -F, -v OFS=, -v k="progs/$n" 'NR==1 { print; next } NR==2 { $2 = k; $3 = "ipl__" k; print; exit }' "$SG_HERE/../../corpus/packages/icon/ipl/ALL.csv" > "$SG_PKG/ALL.csv"
    ca="$( . "$SG_HERE/lib_declared_arena.sh"; declared_memory_table "$SG_PKG/ALL.csv" > "$SG_T/ca.$tag.tsv" && declared_compile_args_from_table "$SG_T/ca.$tag.tsv" "progs/$n" )" \
      || { echo "⛔ GATE REFUSE(2): the fixture's compile_args cell could not be read from the package declaration"; exit 2; }
    [ -f "$SG_PKG/progs/$n.dat" ] && stdin="$SG_PKG/progs/$n.dat"
    ( . "$sd/lib_icon_ipl_isolation.sh"; ipl_isolation_init "$SG_PKG" >/dev/null 2>&1 || exit 2
      export IPL_ISO_SUBDIR=progs IPL_ISO_FIXTURES="$SG_PKG/progs/$n.icn"; declare -a A=(); ipl_argv_read "$SG_PKG/progs/$n.icn" A
      ipl_isolation_run "$out3" 60 "$stdin" "$SG_SCRIP" --run $ca "$SG_PKG/progs/$n.icn" -- "${A[@]}"; echo $? > "$out3.rc"
      "$SG_SCRIP" --compile $ca "$SG_PKG/progs/$n.icn" > "$bin.s" 2>/dev/null < /dev/null \
        && gcc -no-pie "$bin.s" -L"$SG_OUT" -lscrip_rt -Wl,-rpath,"$SG_OUT" -lm -lpthread -o "$bin" 2>/dev/null
      if [ -x "$bin" ]; then ipl_isolation_run "$out4" 60 "$stdin" "$bin" -- "${A[@]}"; echo $? > "$out4.rc"; else echo 99 > "$out4.rc"; : > "$out4"; fi
      ipl_isolation_cleanup )
    rc3="$(cat "$out3.rc" 2>/dev/null || echo 99)"; rc4="$(cat "$out4.rc" 2>/dev/null || echo 99)"
    python3 "$SG_HERE/util_render_error_voice.py" icon < "$out3" > "$out3.v" 2>/dev/null; python3 "$SG_HERE/util_render_error_voice.py" icon < "$out4" > "$out4.v" 2>/dev/null
    ( . "$sd/lib_icon_ipl_isolation.sh"; ipl_graded_cmp "$SG_PKG/progs/$n.icn" "$out3.v" "$SG_REF" ) && { [ -z "$want" ] || [ "$rc3" = "$want" ]; } && v3=PASS
    ( . "$sd/lib_icon_ipl_isolation.sh"; ipl_graded_cmp "$SG_PKG/progs/$n.icn" "$out4.v" "$SG_REF" ) && { [ -z "$want" ] || [ "$rc4" = "$want" ]; } && v4=PASS
  fi
  echo "MINTED=$minted M3=$v3 M4=$v4 REF=$( [ -f "$SG_REF" ] && wc -c < "$SG_REF" || echo -)"
}
