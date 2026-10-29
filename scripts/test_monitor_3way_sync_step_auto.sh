#!/usr/bin/env bash
# test_monitor_3way_sync_step_auto.sh — auto-mode binary sync-step monitor.
#
# Canonical sync-step harness for the SNOBOL4 frontend ladder.  Drives
# any subset of {csn, spl, scr} participants — see PARTICIPANTS env var.
# Replaces the entire pre-SN-26-harness-rewrite family of harnesses
# (test_monitor_3way_sync_step_bin.sh, test_monitor_5way_ipc.sh,
# test_monitor_sync_step.sh, test_monitor_3way.sh) which all required
# inject_traces*.py source preprocessing.  Per RULES.md "Sync-step
# monitor — keyword catch-alls only, no source preprocessing":
#
#   1. NO source preprocessing.  The user's .sno runs unmodified.
#      No inject_traces*.py step.
#
#   2. NO sidecar names file.  Per SN-26-bridge-coverage-e (streaming
#      intern), each participant emits MWK_NAME_DEF records inline on
#      the wire as new names are interned.  The controller builds a
#      per-participant intern table from those wire records.  Spec is
#      now NAME:READY:GO (3-part, no names path).
#
#   3. Env-var driven.  Each runtime reads MONITOR_BIN=1 (scrip only) +
#      MONITOR_READY_PIPE + MONITOR_GO_PIPE and activates its own
#      catch-all trace.  scrip additionally honors SCRIP_TRACE=1 /
#      SCRIP_FTRACE=1 for catch-all activation.
#
# CSNOBOL4 and SPITBOL participants require the SN-26-csn-bridge and
# SN-26-spl-bridge runtime patches to fire on the wire — those landed
# in csnobol4 (session #26) and x64 (session #27).  Both are silently
# no-op when MONITOR_READY_PIPE is unset.
#
# Usage:
#   bash test_monitor_3way_sync_step_auto.sh <file.sno>
#   SCRIP_ONLY=1 bash test_monitor_3way_sync_step_auto.sh <file.sno>
#   PARTICIPANTS="csn spl"     bash test_monitor_3way_sync_step_auto.sh <file.sno>
#   PARTICIPANTS="spl scr"     bash test_monitor_3way_sync_step_auto.sh <file.sno>
#   PARTICIPANTS="csn spl scr" bash test_monitor_3way_sync_step_auto.sh <file.sno>   # default
#   PARTICIPANTS="csn spl dot" bash test_monitor_3way_sync_step_auto.sh <file.sno>   # GOAL-NET-BEAUTY-SELF
#
# Environment overrides:
#   PARTICIPANTS="..."    — space-separated list from {csn, spl, scr, dot} in
#                           desired order.  First entry is the oracle
#                           the controller compares against.
#                           Default: "csn spl scr" (3-way).
#   SCRIP_ONLY=1          — alias for PARTICIPANTS="scr" (back-compat).
#   MONITOR_TIMEOUT=N     — per-participant timeout (default 15).
#   STDIN_SRC=path        — file fed to each participant on stdin.
#                           Default: /dev/null, or <file>.input if it exists.
#   SNO4_DLL=path         — Snobol4.dll location (default $SNO4_REPO/Snobol4/bin/Release/net10.0/Snobol4.dll).
#
# Exit:
#   0 — all participants agreed
#   1 — divergence
#   2 — timeout / EOF on a participant / setup failure
#   3 — protocol error
#
# Requires (run once per session):
#   bash ../harness/scripts/install_system_packages.sh
#   bash ../harness/scripts/build_scrip.sh
# And for full 3-way (when bridges land):
#   bash ../harness/scripts/build_csnobol4_oracle.sh   # with SN-26-csn-bridge applied
#   bash ../harness/scripts/build_spitbol_oracle.sh    # with SN-26-spl-bridge applied
#
# AUTHORS: Lon Jones Cherryholmes · Claude Sonnet 4.6  DATE: 2026-04-26
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.

set -uo pipefail

SNO=${1:?Usage: test_monitor_3way_sync_step_auto.sh <file.sno> [--trail N]}
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MON_DIR="$HERE/monitor"

# --trail N  (optional second argument) — override how many last-agreed events
# to print on DIVERGE.  Sets MONITOR_LAST_AGREE_TRAIL for the controller.
# Default: 5 (controller default).  Env var also accepted directly.
if [[ "${2:-}" == "--trail" && -n "${3:-}" ]]; then
    export MONITOR_LAST_AGREE_TRAIL="${3}"
fi

X64_DIR="${X64_DIR:-$S4A/x64}"
SPITBOL="$X64_DIR/bin/sbl"
CSNOBOL4="$S4A/csnobol4/snobol4"
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
SNO4_REPO="${SNO4_REPO:-$S4A/snobol4dotnet}"
SNO4_DLL="${SNO4_DLL:-$SNO4_REPO/Snobol4/bin/Release/net10.0/Snobol4.dll}"
ICON_MON="${ICON_MON_ROOT:-$S4A/icon-mon}"
GPROLOG_MON="${GPROLOG_MON_ROOT:-$S4A/gprolog-mon}"
FPC_MON="${FPC_MON_ROOT:-$S4A/fpc-mon}"
RAKUDO_MON="${RAKUDO_MON_ROOT:-$S4A/rakudo-mon}"
SWIPL_MON="${SWIPL_MON_ROOT:-$S4A/swipl-mon}"
INC="${INC:-$S4E/corpus/include}"

TIMEOUT="${MONITOR_TIMEOUT:-15}"
SCRIP_ONLY="${SCRIP_ONLY:-0}"

# PARTICIPANTS env var (preferred):  e.g. "csn spl scr", "csn spl", "spl scr".
# SCRIP_ONLY=1 is back-compat alias for PARTICIPANTS="scr".
if [[ -n "${PARTICIPANTS:-}" ]]; then
    read -r -a PARTICIPANTS <<< "$PARTICIPANTS"
elif [[ "$SCRIP_ONLY" = "1" ]]; then
    PARTICIPANTS=(scr)
else
    PARTICIPANTS=(csn spl scr)   # default 3-way; first entry is oracle
fi

# Validate participant names.
for p in "${PARTICIPANTS[@]}"; do
    case "$p" in
        csn|spl|scr|dot|scr3|scr4|rkx|icx|gpx|swx|fpx) ;;
        *) echo "FAIL unknown participant '$p' (allowed: csn, spl, scr, dot, scr3, scr4, rkx, icx, gpx, swx, fpx)"; exit 2 ;;
    esac
done

want_csn=0; want_spl=0; want_scr=0; want_dot=0; want_rkx=0; want_icx=0; want_gpx=0; want_swx=0; want_fpx=0
for p in "${PARTICIPANTS[@]}"; do
    case "$p" in
        csn) want_csn=1 ;;
        spl) want_spl=1 ;;
        scr) want_scr=1 ;;
        scr3) want_scr3=1 ;;
        scr4) want_scr4=1 ;;
        dot) want_dot=1 ;;
        rkx) want_rkx=1 ;;
        icx) want_icx=1 ;;
        gpx) want_gpx=1 ;;
        swx) want_swx=1 ;;
        fpx) want_fpx=1 ;;
    esac
done

# ── Prerequisites ──────────────────────────────────────────────────────
[[ -f "$SNO" ]]                          || { echo "FAIL source not found: $SNO"; exit 2; }
[[ -f "$MON_DIR/monitor_sync_bin.py" ]]  || { echo "FAIL monitor_sync_bin.py missing"; exit 2; }
[[ "$want_scr" = "1" ]] && [[ ! -x "$SCRIP" ]]    && { echo "FAIL scrip not built: $SCRIP — run build_scrip.sh"; exit 2; }
[[ "$want_csn" = "1" ]] && [[ ! -x "$CSNOBOL4" ]] && { echo "FAIL csnobol4 not built: $CSNOBOL4"; exit 2; }
[[ "$want_spl" = "1" ]] && [[ ! -x "$SPITBOL" ]]  && { echo "FAIL spitbol not built: $SPITBOL"; exit 2; }
[[ "$want_dot" = "1" ]] && [[ ! -f "$SNO4_DLL" ]] && { echo "FAIL snobol4dotnet not built: $SNO4_DLL — dotnet build Snobol4/Snobol4.csproj -c Release -p:EnableWindowsTargeting=true"; exit 2; }
[[ "$want_dot" = "1" ]] && ! command -v dotnet >/dev/null 2>&1 && { echo "FAIL dotnet command missing — apt-get install -y dotnet-sdk-10.0"; exit 2; }
[[ "$want_rkx" = "1" ]] && [[ ! -x "$RAKUDO_MON/bin/raku" ]] && { echo "FAIL instrumented Rakudo fork not built at $RAKUDO_MON/bin/raku -- bash ../harness/scripts/monitor/oracles/build_rakudo_mon.sh <prefix> (RAKUDO_MON_ROOT names the prefix)"; exit 2; }
[[ "$want_icx" = "1" ]] && { [[ ! -x "$ICON_MON/bin/icont" ]] || [[ ! -x "$ICON_MON/bin/iconx" ]]; } && { echo "FAIL instrumented Icon fork not built at $ICON_MON/bin/{icont,iconx} -- bash ../harness/scripts/monitor/oracles/build_icon_mon.sh <prefix> (ICON_MON_ROOT names the prefix)"; exit 2; }
[[ "$want_gpx" = "1" ]] && [[ ! -x "$GPROLOG_MON/bin/gplc" ]] && { echo "FAIL instrumented GNU Prolog fork not built at $GPROLOG_MON/bin/gplc -- bash ../harness/scripts/monitor/oracles/build_gprolog_mon.sh <prefix> (GPROLOG_MON_ROOT names the prefix)"; exit 2; }
[[ "$want_swx" = "1" ]] && [[ ! -x "$SWIPL_MON/bin/swipl" ]] && { echo "FAIL instrumented SWI-Prolog fork not built at $SWIPL_MON/bin/swipl -- bash ../harness/scripts/monitor/oracles/build_swipl_mon.sh <prefix> (SWIPL_MON_ROOT names the prefix)"; exit 2; }
[[ "$want_fpx" = "1" ]] && [[ ! -x "$FPC_MON/bin/fpc" ]] && { echo "FAIL instrumented Free Pascal fork not built at $FPC_MON/bin/fpc -- bash ../harness/scripts/monitor/oracles/build_fpc_mon.sh <prefix> (FPC_MON_ROOT names the prefix)"; exit 2; }
:

# ⛔ SCRATCH ON /home, NOT BARE /tmp, WITH CLEANUP THAT SURVIVES A KILL (row icon-sweep-scratch-hardening, s267).
# /tmp is the 125G ROOT partition; /home is a separate 503G one, and nothing in the word "/tmp" says so.
# ⭐ THIS SCRIPT IS NOT A HYPOTHETICAL: the s267 disk-full cleanup found a stale `monitor_auto` scratch dir holding
# 1.8GB, the fourth-largest consumer on the full filesystem. Three participants each get their full stdout+stderr
# redirected here (`> "$TMP/<eng>.out"`), unbounded, and a monitor run that hangs is killed by `timeout` -- which is
# precisely when a success-path `rm -rf` never runs. Same three-part shape as honest_icon_correctness.sh.
SCRATCH_ROOT="${S4E_SCRATCH:-$S4E/.scratch}"
mkdir -p "$SCRATCH_ROOT" 2>/dev/null || { echo "REFUSING: cannot create scratch root $SCRATCH_ROOT -- set S4E_SCRATCH to a writable dir ON /home. Refusing rather than falling back to /tmp, which is the root partition." >&2; exit 2; }
TMP=$(mktemp -d "$SCRATCH_ROOT/monitor_auto_XXXXXX")
monitor_auto_cleanup() { [ "${MONITOR_KEEP_TMP:-0}" = "1" ] && return 0; [ -n "${TMP:-}" ] && [ -d "$TMP" ] && rm -rf "$TMP"; return 0; }
trap monitor_auto_cleanup EXIT INT TERM
# ⛔ BOUND EVERY PARTICIPANT'S WRITE. A diverging engine writes without limit for the whole timeout window; capping
# via `ulimit -f` (512-byte blocks) bounds the write itself rather than inserting a pipe between the engine and its
# file, which matters here because the participants are backgrounded and their fds are wired to fifos.
MON_OUT_CAP="${MON_OUT_CAP:-268435456}"
ulimit -f $(( MON_OUT_CAP / 512 )) 2>/dev/null || true

base="$(basename "$SNO")"; base="${base%.*}"
STDIN_SRC="${STDIN_SRC:-/dev/null}"
[[ -n "${MONITOR_STDIN:-}" && -f "${MONITOR_STDIN}" ]] && STDIN_SRC="$MONITOR_STDIN"
[[ "$STDIN_SRC" = "/dev/null" && -f "${SNO%.*}.input" ]] && STDIN_SRC="${SNO%.*}.input"
# ⭐ THE UNIT'S DECLARATION REACHES EVERY PARTICIPANT (ceo CEO-1353, RULES.md clause 8 (g); the coo 2026-10-03): the SCRIP participants run
# at the heap and stack <stem>.heap / <stem>.stack declare (-d/-s after --run, leading a compiled participant's arguments), and the oracle
# participants at the knobs the reader admits for them -- <stem>.oracle_args for spl (sbl -s/-d), <stem>.oracle_env for icx and gpx. Until
# this every participant ran at its default, so a unit that needs its declared stack died in the monitor where it passes on its board.
. "$HERE/lib_declared_arena.sh" || { echo "FAIL cannot load lib_declared_arena.sh -- the one reader of a declared heap and stack"; exit 2; }
_mon_sw="$(declared_switches_beside "$SNO")" || { echo "FAIL $SNO: a .heap or .stack sidecar the reader refuses"; exit 2; }
_mon_oa="$(declared_oracle_args_beside "$SNO")" || { echo "FAIL $SNO: a .oracle_args sidecar the reader refuses"; exit 2; }
_mon_oe="$(declared_oracle_env_beside "$SNO")" || { echo "FAIL $SNO: a .oracle_env sidecar the reader refuses"; exit 2; }
SSW=(); [[ -n "$_mon_sw" ]] && read -r -a SSW <<<"$_mon_sw"
OARGS=(); [[ -n "$_mon_oa" ]] && read -r -a OARGS <<<"$_mon_oa"
OENV=(); [[ -n "$_mon_oe" ]] && read -r -a OENV <<<"$_mon_oe"
# the runtime this harness links against is its own repository's (the coo 2026-10-03, CEO-1496): $S4E/SCRIP/out is a sibling checkout's
# when the harness runs from a worktree, so a worktree's participant linked a runtime the worktree never built
SD="$(cd "$HERE/../../SCRIP" && pwd)"

echo "[auto] program:    $base"
echo "[auto] tmp:        $TMP"
echo "[auto] mode:       ${PARTICIPANTS[*]}"
echo "[auto] stdin:      $STDIN_SRC"

# ── Create per-participant FIFO pairs and names-out paths ──────────────
for p in "${PARTICIPANTS[@]}"; do
    mkfifo "$TMP/$p.ready"
    mkfifo "$TMP/$p.go"
    : > "$TMP/$p.names"   # touch — the participant overwrites at exit
done

# ── Launch participants in background ──────────────────────────────────

PIDS=()

# CSNOBOL4 — oracle when present.
# Requires SN-26-csn-bridge applied to v311.sil (already in current
# csnobol4 HEAD as of session #25/#26).  The bridge is silently no-op
# when MONITOR_READY_PIPE is unset.
if [[ "$want_csn" = "1" ]]; then
    MONITOR_BIN=1 \
    MONITOR_READY_PIPE="$TMP/csn.ready" \
    MONITOR_GO_PIPE="$TMP/csn.go" \
    MONITOR_NAMES_OUT="$TMP/csn.names" \
        timeout "$((TIMEOUT*2))" "$CSNOBOL4" -bf -P256k -S 64k -I"$INC" "$SNO" \
        < "$STDIN_SRC" > "$TMP/csn.out" 2> "$TMP/csn.err" &
    PIDS+=($!)
fi

# SPITBOL x64 — secondary oracle.
# Requires SN-26-spl-bridge applied to sbl.min (already in current x64
# HEAD as of session #27).  Silently no-op when env vars unset.
if [[ "$want_spl" = "1" ]]; then
    MONITOR_BIN=1 \
    MONITOR_READY_PIPE="$TMP/spl.ready" \
    MONITOR_GO_PIPE="$TMP/spl.go" \
    MONITOR_NAMES_OUT="$TMP/spl.names" \
    SETL4PATH=".:$INC" \
    ${MONITOR_PM:+SPL_PM_TRACE=1} \
        timeout "$((TIMEOUT*2))" "$SPITBOL" -bf ${OARGS[@]+"${OARGS[@]}"} "$SNO" \
        < "$STDIN_SRC" > "$TMP/spl.out" 2> "$TMP/spl.err" &
    PIDS+=($!)
fi

# scrip --run by default; --run / --run via SCRIP_RUN_FLAG override
# (SN-32: same harness drives SM/native codegen runs without forking the file).
# Catch-all activated via SCRIP_TRACE/SCRIP_FTRACE only;
# no source modification, no LOAD-chain.
# ⛔ SCRIP_TRACE IS THE PARTICIPANT'S EVENT BUDGET AND IT MUST NOT RUN OUT MID-RUN (coo 2026-09-25, on hq_snobol4's report): its
# default here was 99999, so every SCRIP participant stopped emitting at event 99,999 while the oracle went on -- aisnobol TEST.sno
# (1,316,102 events) and a plain 60,000-iteration loop both died at EXACTLY step 100000. Worse than a short run: past the budget
# comm_var falls through to the TEXT-protocol mon_send, so text landed on the binary wire (value_len 0x33333333, "3333") and the
# controller read a torn header. The default is now what `scrip --trace` itself sets, 2000000000; the loop agrees to step 180005.
if [[ "$want_scr" = "1" ]]; then
    SCR_RUN_FLAG="${SCRIP_RUN_FLAG:---run}"
    if [[ "$SCR_RUN_FLAG" == "--m4" || "${SCRIP_M4:-0}" == "1" ]]; then
        # s196 m4 participant (Lon: m4 in the 2-way monitor outranks m3).  Compile with
        # --monitor so the inline WRITE taps + stmt/label/call taps BAKE into the .s
        # (shared codegen: identical instrumentation to m3), link against libscrip_rt.so
        # (whose core init reads MONITOR_READY_PIPE at run time), run the binary.
        ( cd "$(dirname "$(realpath "$SNO")")" && timeout -k 5 "$TIMEOUT" "$SCRIP" --trace --compile --monitor --out="$TMP/scr.s" "$(realpath "$SNO")" </dev/null ) > "$TMP/scr.cc.out" 2>&1 \
            || { echo "FAIL m4 compile: $(tail -2 "$TMP/scr.cc.out")"; exit 2; }
        gcc -no-pie "$TMP/scr.s" -L"$SD/out" -lscrip_rt -Wl,-rpath,"$SD/out" -lm -o "$TMP/scr.bin" >> "$TMP/scr.cc.out" 2>&1 \
            || { echo "FAIL m4 link: $(tail -2 "$TMP/scr.cc.out")"; exit 2; }
        MONITOR_BIN=1 \
        MONITOR_READY_PIPE="$TMP/scr.ready" \
        MONITOR_GO_PIPE="$TMP/scr.go" \
        MONITOR_NAMES_OUT="$TMP/scr.names" \
        SCRIP_TRACE="${SCRIP_TRACE:-2000000000}" \
        SNO_LIB="$INC" \
            timeout "$((TIMEOUT*2))" "$TMP/scr.bin" ${SSW[@]+"${SSW[@]}"} \
            < "$STDIN_SRC" > "$TMP/scr.out" 2> "$TMP/scr.err" &
        PIDS+=($!)
    else
    MONITOR_BIN=1 \
    MONITOR_READY_PIPE="$TMP/scr.ready" \
    MONITOR_GO_PIPE="$TMP/scr.go" \
    MONITOR_NAMES_OUT="$TMP/scr.names" \
    SCRIP_TRACE="${SCRIP_TRACE:-2000000000}" \
    SNO_LIB="$INC" \
        timeout "$((TIMEOUT*2))" "$SCRIP" --trace "$SCR_RUN_FLAG" ${SSW[@]+"${SSW[@]}"} "$SNO" \
        < "$STDIN_SRC" > "$TMP/scr.out" 2> "$TMP/scr.err" &
    PIDS+=($!)
    fi
fi

# snobol4dotnet — runtime under test for GOAL-NET-BEAUTY-SELF.
# MonitorIpc.cs reads MONITOR_READY_PIPE / MONITOR_GO_PIPE at first emit;
# silently no-op if either is unset (S-2-bridge-1 dormancy guarantee).
# Fire-points landed:
#   - Executive.Assign chokepoint  → VALUE on every lvalue store (bridge-2/3)
#   - ExecuteProgramDefinedFunction → CALL/EmitValue/RETURN at fn entry/exit (bridge-4)
#   - InitStatementMsil + OpCode.Init → LABEL on every stmt entry (coverage-f)
#   - InternName → MWK_NAME_DEF on first id use (coverage-e, streaming intern)
# Run with -bf for case-sensitive identifiers (matches csn/spl invocation).
# ⭐ scr3 / scr4 (ceo 2026-09-23, CEO-1185, Lon: "Get IPC sync-step monitor working for all languages"): TWO SCRIP participants
# facing each other -- mode 3 (--run) against mode 4 (the compiled binary) -- on ONE source of ANY frontend, both built with
# --trace so the shared hooks (rt_trace_stmt/_value/_call/_return, MONITOR-BINARY-DESIGN.md § THE PLUG INTERFACE) put every
# statement, assignment, call and return on the binary wire; the SNOBOL4 path's own events ride the same wire. No oracle bridge
# is needed, which is why this is every language's FIRST arm: a mode-3/mode-4 divergence is a MODES-MAY-DIVERGE semantic drift.
if [[ "${want_scr3:-0}" = "1" ]]; then
    MONITOR_BIN=1 \
    MONITOR_READY_PIPE="$TMP/scr3.ready" \
    MONITOR_GO_PIPE="$TMP/scr3.go" \
    MONITOR_NAMES_OUT="$TMP/scr3.names" \
    SCRIP_TRACE="${SCRIP_TRACE:-2000000000}" \
    SNO_LIB="$INC" \
        timeout "$((TIMEOUT*2))" "$SCRIP" --trace --run ${SSW[@]+"${SSW[@]}"} "$SNO" \
        < "$STDIN_SRC" > "$TMP/scr3.out" 2> "$TMP/scr3.err" &
    PIDS+=($!)
fi
if [[ "${want_scr4:-0}" = "1" ]]; then
    ( cd "$(dirname "$(realpath "$SNO")")" && timeout -k 5 "$TIMEOUT" "$SCRIP" --trace --compile --monitor --out="$TMP/scr4.s" "$(realpath "$SNO")" </dev/null ) > "$TMP/scr4.cc.out" 2>&1 \
        || { echo "FAIL scr4 compile: $(tail -2 "$TMP/scr4.cc.out")"; exit 2; }
    gcc "$TMP/scr4.s" -L"$SD/out" -lscrip_rt -Wl,-rpath,"$SD/out" -lm -o "$TMP/scr4.bin" >> "$TMP/scr4.cc.out" 2>&1 \
        || { echo "FAIL scr4 link: $(tail -2 "$TMP/scr4.cc.out")"; exit 2; }
    MONITOR_BIN=1 \
    MONITOR_READY_PIPE="$TMP/scr4.ready" \
    MONITOR_GO_PIPE="$TMP/scr4.go" \
    MONITOR_NAMES_OUT="$TMP/scr4.names" \
    SCRIP_TRACE="${SCRIP_TRACE:-2000000000}" \
    SNO_LIB="$INC" \
        timeout "$((TIMEOUT*2))" "$TMP/scr4.bin" ${SSW[@]+"${SSW[@]}"} \
        < "$STDIN_SRC" > "$TMP/scr4.out" 2> "$TMP/scr4.err" &
    PIDS+=($!)
fi
if [[ "$want_dot" = "1" ]]; then
    MONITOR_BIN=1 \
    MONITOR_READY_PIPE="$TMP/dot.ready" \
    MONITOR_GO_PIPE="$TMP/dot.go" \
    ${MONITOR_PM:+MONITOR_PM_TRACE=1} \
        timeout "$((TIMEOUT*2))" dotnet "$SNO4_DLL" -bf "$SNO" \
        < "$STDIN_SRC" > "$TMP/dot.out" 2> "$TMP/dot.err" &
    PIDS+=($!)
fi

# ⭐ rkx (cfo 2026-09-23, Lon: "Build the Rakudo IPC sync-step monitor inside Rakudo just like CEO did for Icon and Prolog"):
# the Rakudo 2026.05 fork built by ../harness/scripts/monitor/oracles/build_rakudo_mon.sh -- the compiler injects four extops (monitor_rkx.c
# beside perl6_ops.c) into the user's compilation unit only: p6monstmt before every statement of every statement list, p6moncall at
# every named routine's entry, p6monret around every routine body, p6monval after every store to a named variable; CORE and every
# precompilation are never instrumented. The extops speak the shared monitor_ipc_lib.c wire and are silent no-ops when the pipes
# are unset (the fork's untraced output is the pristine oracle's, proven by the build script's control arm). No compile step: raku
# compiles and runs the witness in one process.
if [[ "${want_rkx:-0}" = "1" ]]; then
    RKX_SRC="$(realpath "$SNO")"
    MONITOR_READY_PIPE="$TMP/rkx.ready" \
    MONITOR_GO_PIPE="$TMP/rkx.go" \
    MONITOR_NAMES_OUT="$TMP/rkx.names" \
        timeout "$((TIMEOUT*2))" "$RAKUDO_MON/bin/raku" "$RKX_SRC" \
        < "$STDIN_SRC" > "$TMP/rkx.out" 2> "$TMP/rkx.err" &
    PIDS+=($!)
fi

# ⭐ icx (ceo 2026-09-23, Lon: "Each oracle must be INSTRUMENTED with IPC COMM calls"): the Arizona icont/iconx fork built by
# ../harness/scripts/monitor/oracles/build_icon_mon.sh -- icont emits a stmt opcode at every statement of every statement list, iconx fires
# the four hooks (statement, value, call, return) through the shared monitor_ipc_lib.c on the READY/GO wire; silent no-op when the
# pipes are unset (the fork's untraced output is the pristine oracle's, proven by the build script's control arm).
if [[ "${want_icx:-0}" = "1" ]]; then
    ICX_SRC="$(realpath "$SNO")"
    # ⭐ icx LINKS WHAT SCRIP LINKS (hq_icon 2026-09-25, ceo CEO-1272 (b)). icont links ucode, never source, so a program whose
    # `link` names a library shipped beside it (every CEO-1269 NAME_driver, io_lib, lists_lib ...) failed to compile here with
    # "cannot resolve reference to file 'io_lib.u1'" and the bracket refused. Every library the program reaches is now found in
    # SCRIP's OWN search order (src/parsers/icon/icon_driver.c icn_link_open: IPATH, ICONPATH, the IPL procs beside the scrip
    # binary, then the linking file's directory), translated into $TMP/icxlib, and icont links from there -- so both participants
    # run the same library source, and nothing is written beside the program. Measured on the 24 linked Arizona programs: icx
    # builds all 24 and each answers as SCRIP does, under the IPATH the runner gives a driver.
    ICX_LIB="$TMP/icxlib"; mkdir -p "$ICX_LIB"
    ICX_PROCS="$(cd "$(dirname "$(realpath "$SCRIP")")" && pwd)/../corpus/packages/icon/ipl/procs"
    icx_links() { sed -E 's/#.*//' "$1" | grep -E '^[[:space:]]*link[[:space:]]' | sed -E 's/^[[:space:]]*link[[:space:]]+//; s/[;,"]/ /g' | tr -s ' \t' '\n' | sed '/^$/d'; }
    icx_find() { local nm="$1" from="$2" d; local IFS=':'
        for d in ${IPATH:-} ${ICONPATH:-}; do [ -n "$d" ] && [ -f "$d/$nm.icn" ] && { realpath "$d/$nm.icn"; return; }; done
        [ -f "$ICX_PROCS/$nm.icn" ] && { realpath "$ICX_PROCS/$nm.icn"; return; }
        [ -f "$(dirname "$from")/$nm.icn" ] && realpath "$(dirname "$from")/$nm.icn"; }
    icx_todo="$(icx_links "$ICX_SRC" | sed "s|^|$ICX_SRC\t|")"; icx_seen=" "
    while [ -n "$icx_todo" ]; do
        icx_next=""
        while IFS=$'\t' read -r icx_from icx_nm; do
            [ -n "$icx_nm" ] || continue; case "$icx_seen" in *" $icx_nm "*) continue ;; esac; icx_seen="$icx_seen$icx_nm "
            icx_f="$(icx_find "$icx_nm" "$icx_from")"; [ -n "$icx_f" ] || continue
            ( cd "$ICX_LIB" && timeout -k 5 "$TIMEOUT" "$ICON_MON/bin/icont" -s -c "$icx_f" ) >> "$TMP/icx.cc.out" 2>&1 \
                || { echo "FAIL icx compile of linked library $icx_f: $(tail -2 "$TMP/icx.cc.out")"; exit 2; }
            icx_next="$icx_next$(icx_links "$icx_f" | sed "s|^|$icx_f\t|")"$'\n'
        done <<< "$icx_todo"
        icx_todo="$(printf '%s' "$icx_next" | sed '/^$/d')"
    done
    ( cd "$(dirname "$ICX_SRC")" && IPATH="$ICX_LIB" timeout -k 5 "$TIMEOUT" "$ICON_MON/bin/icont" -s -o "$TMP/icx.bin" "$ICX_SRC" ) >> "$TMP/icx.cc.out" 2>&1 \
        || { echo "FAIL icx compile: $(tail -2 "$TMP/icx.cc.out")"; exit 2; }
    MONITOR_READY_PIPE="$TMP/icx.ready" \
    MONITOR_GO_PIPE="$TMP/icx.go" \
    MONITOR_NAMES_OUT="$TMP/icx.names" \
        env ${OENV[@]+"${OENV[@]}"} timeout "$((TIMEOUT*2))" "$ICON_MON/bin/iconx" "$TMP/icx.bin" \
        < "$STDIN_SRC" > "$TMP/icx.out" 2> "$TMP/icx.err" &
    PIDS+=($!)
fi

# ⭐ gpx (ceo 2026-09-23, CEO-1189; Lon: "Build IPC sync-step monitor into GNU Prolog just like you did for Icon"): the GNU Prolog
# fork built by ../harness/scripts/monitor/oracles/build_gprolog_mon.sh -- its pl2wam injects a call_c fire-point at every user predicate's
# entry (call), before every body goal of every user clause (statement, the clause's source line) and at the end of every clause
# (return); the fire-points (monitor_gpx.c in EnginePl) speak the shared monitor_ipc_lib.c wire and are silent no-ops when the
# pipes are unset (the build script's control arm). gplc finds pl2wam/wam2ma/ma2asm by PATH search, so the fork's bin is
# prepended; the witness is compiled into a no-top-level binary (the initialization goal runs, then the process exits).
if [[ "${want_gpx:-0}" = "1" ]]; then
    GPX_SRC="$(realpath "$SNO")"
    ( cd "$(dirname "$GPX_SRC")" && PATH="$GPROLOG_MON/bin:$PATH" timeout -k 5 "$TIMEOUT" "$GPROLOG_MON/bin/gplc" --no-top-level -o "$TMP/gpx.bin" "$GPX_SRC" ) > "$TMP/gpx.cc.out" 2>&1 \
        || { echo "FAIL gpx compile: $(tail -2 "$TMP/gpx.cc.out")"; exit 2; }
    MONITOR_READY_PIPE="$TMP/gpx.ready" \
    MONITOR_GO_PIPE="$TMP/gpx.go" \
    MONITOR_NAMES_OUT="$TMP/gpx.names" \
        env ${OENV[@]+"${OENV[@]}"} timeout "$((TIMEOUT*2))" "$TMP/gpx.bin" \
        < "$STDIN_SRC" > "$TMP/gpx.out" 2> "$TMP/gpx.err" &
    PIDS+=($!)
fi

# ⭐ swx (cfo 2026-09-24, CEO-1236; Lon: "To complete the IPC sync-step monitor for Prolog we must instrument SWIPL in the same
# manner as Gnu Prolog"): the SWI-Prolog fork built by ../harness/scripts/monitor/oracles/build_swipl_mon.sh -- its loader stores every clause
# of the program file with '$mon_stmt'(Line) before each body goal (the goal's own first line, from the reader's subterm positions)
# and '$mon_ret' at the clause's end, and its VM fires CALL at the entry of every predicate so stored (pl-vmi.c,
# depart_or_retry_continue); library, dynamic and multifile predicates and directives are never events. The fire-points
# (monitor_swx.c) speak the shared monitor_ipc_lib.c wire, and the loader stores a clause unchanged unless the READY pipe is named,
# so the fork's untraced run is the pristine oracle's (the build script's control arm). No compile step: swipl loads and runs it.
if [[ "${want_swx:-0}" = "1" ]]; then
    SWX_SRC="$(realpath "$SNO")"
    MONITOR_READY_PIPE="$TMP/swx.ready" \
    MONITOR_GO_PIPE="$TMP/swx.go" \
    MONITOR_NAMES_OUT="$TMP/swx.names" \
        timeout "$((TIMEOUT*2))" "$SWIPL_MON/bin/swipl" "$SWX_SRC" \
        < "$STDIN_SRC" > "$TMP/swx.out" 2> "$TMP/swx.err" &
    PIDS+=($!)
fi

# ⭐ fpx (coo 2026-09-23, on Lon's word to the coo at 06:32 CDT: "Build the Free Pascal Compiler (FPC) IPC sync-step monitor inside
# FPC just like CEO did for Icon and Prolog"): the Free Pascal fork built by ../harness/scripts/monitor/oracles/build_fpc_mon.sh -- under -gi
# its compiler injects a fire-point at every element of every statement list (statement, the statement's own source line), after
# every store to a named variable and at the top of every for-loop iteration (value), at every user procedure's entry (call) and
# exit label (return, with the function's result); the fire-points (rtl/inc/monipc.inc, Pascal over the system unit's own
# syscalls) speak the shared monitor_ipc_lib.c wire and are silent no-ops when the pipes are unset (the build script's control
# arm). The witness is compiled -Miso as the Pascal board compiles it, into the harness's scratch (-FE), never beside the source.
if [[ "${want_fpx:-0}" = "1" ]]; then
    FPX_SRC="$(realpath "$SNO")"
    ( cd "$TMP" && timeout -k 5 "$TIMEOUT" "$FPC_MON/bin/fpc" -Miso -gi -v0 -FE"$TMP" -o"$TMP/fpx.bin" "$FPX_SRC" ) > "$TMP/fpx.cc.out" 2>&1 \
        || { echo "FAIL fpx compile: $(tail -2 "$TMP/fpx.cc.out")"; exit 2; }
    MONITOR_READY_PIPE="$TMP/fpx.ready" \
    MONITOR_GO_PIPE="$TMP/fpx.go" \
    MONITOR_NAMES_OUT="$TMP/fpx.names" \
        timeout "$((TIMEOUT*2))" "$TMP/fpx.bin" \
        < "$STDIN_SRC" > "$TMP/fpx.out" 2> "$TMP/fpx.err" &
    PIDS+=($!)
fi

# ── Launch controller using the SN-26-bridge-coverage-e 3-part spec ────
# Names live on the wire (MWK_NAME_DEF records); no sidecar names path
# in the spec.  All four runtimes (csn, spl, scr, dot) use streaming
# intern as of snobol4dotnet @ 8e5ff9e.
SPECS=()
for p in "${PARTICIPANTS[@]}"; do
    SPECS+=("$p:$TMP/$p.ready:$TMP/$p.go")
done

# ⛔⭐ THE CONTROLLER IS BOUNDED, BECAUSE IT USED TO BE THE THING THAT HUNG (hq_T 2026-09-09,
# ceo brief `the-ipc-sync-step-monitor-does-not-run-and-lon-is-counting-on-it`).  Every
# PARTICIPANT above carries `timeout $((TIMEOUT*2))`; the controller carried none, and a
# bare `wait` on it is unbounded.  So the one process with no bound was the one that blocked
# -- on a FIFO open whose writer had already exited -- and the whole harness inherited its
# hang.  ⭐ The general form worth keeping: bounding N-1 of N cooperating processes bounds
# NOTHING; the unbounded one becomes the duration of the job.
CTRL_TIMEOUT="${MONITOR_CTRL_TIMEOUT:-$((TIMEOUT*4))}"
MONITOR_SNO_FILE="$([[ "$SNO" == *.sno || "$SNO" == *.spt || "$SNO" == *.sbl ]] && echo "$SNO")" \
MONITOR_INC_DIR="$(dirname "$(realpath "$SNO")"):$INC" \
    timeout -k 5 "$CTRL_TIMEOUT" python3 "$MON_DIR/monitor_sync_bin.py" "${SPECS[@]}" > "$TMP/ctrl.out" 2>&1 &
CTRL_PID=$!

# ── Wait + reap ────────────────────────────────────────────────────────
wait "$CTRL_PID"
CTRL_RC=$?

# ⛔ A TIMED-OUT CONTROLLER IS A REFUSAL (rc=2), NEVER A RESULT.  rc=124 means the controller
# could not measure, which must never reach a caller as 0 (agreed) or 1 (diverged).
if [[ "$CTRL_RC" = "124" ]]; then
    echo "REFUSING(2) [monitor_auto]: controller did not finish within ${CTRL_TIMEOUT}s -- it could not measure, so this is NOT a verdict." >&2
    CTRL_RC=2
fi

# Make sure participants are reaped — SIGTERM in case they're still
# blocked on the (now-closed) go FIFO.
for pid in "${PIDS[@]}"; do kill "$pid" 2>/dev/null || true; done
wait 2>/dev/null || true

# ── Report ─────────────────────────────────────────────────────────────
echo
echo "── controller output ──"
cat "$TMP/ctrl.out"

for p in "${PARTICIPANTS[@]}"; do
    if [[ -s "$TMP/$p.out" ]]; then
        echo
        echo "── $p stdout (head) ──"
        head -20 "$TMP/$p.out"
    fi
    if [[ -s "$TMP/$p.err" ]]; then
        echo "── $p stderr (head) ──"
        head -20 "$TMP/$p.err"
    fi
    if [[ -s "$TMP/$p.names" ]]; then
        n=$(wc -l < "$TMP/$p.names")
        echo "── $p names ($n) ──"
        head -10 "$TMP/$p.names"
    fi
done

# Preserve artifacts.
rm -rf /tmp/monitor_auto_last
cp -a "$TMP" /tmp/monitor_auto_last
echo
echo "[auto] artefacts:  /tmp/monitor_auto_last/"
echo "[auto] exit:       $CTRL_RC"

exit "$CTRL_RC"
