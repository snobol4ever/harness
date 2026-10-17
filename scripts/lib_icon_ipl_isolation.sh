# lib_icon_ipl_isolation.sh -- THE ONE AUTHORITY for executing a corpus/packages/icon/ipl/progs/*.icn
# program (or a SCRIP binary compiled from one), never re-derived per caller.
#
# ⛔⛔ WHY THIS EXISTS: IPL ships several programs that MUTATE THEIR OWN CWD as documented, normal
# behavior -- progs/upper.icn and progs/lower.icn rename EVERY file in cwd to upper/lower case; at least
# one other writes a fixed-name scratch file. A first attempt at util_cut_icon_ipl_refs.sh ran the Icon
# oracle with $PKG/progs as cwd directly (matching test_icon_arizona_suite.sh's cwd-fidelity pattern,
# which is safe for Arizona because its fixtures only ever ADD litter, never rename existing files) and
# it renamed all 275 vendored .icn sources to UPPERCASE in place -- `git status` showed 275 D + 279 ??
# before it was caught and reverted. Arizona's snapshot-diff cleanup does not protect EXISTING tracked
# files from being renamed or overwritten, so it is not sufficient for IPL. ANY caller that executes an
# IPL progs/ program (as source, via the oracle, or as a SCRIP-compiled binary) with progs/ as its cwd
# MUST go through ipl_isolation_run below, never `cd "$PKG/progs" && ...` directly -- this is the same
# "loud refusal, never a private re-derivation" law lib_oracle_flags.sh already applies to oracle paths.
#
# USAGE:
#   . lib_icon_ipl_isolation.sh
#   ipl_isolation_init "$PKG"          # once; builds the pristine template, registers its own cleanup
#   ipl_isolation_run "$OUTFILE" "$TIMEOUT" "$STDIN" cmd arg...
#       runs `cmd arg...` with a FRESH scratch copy's progs/ as cwd, ICONPATH set to the scratch
#       siblings (progs:procs:gprocs:incl:gincl), stdin from $STDIN (pass /dev/null for none -- callers
#       decide, this lib never guesses), under `timeout $TIMEOUT`. Combined stdout+stderr go to
#       $OUTFILE. Returns the command's own exit status (124 = timeout). The scratch copy is destroyed
#       before returning, pass or fail -- a self-mutating program can only ever damage a copy already
#       bound for deletion, never the tracked tree.
#       ⭐ NAME.dat STDIN SIDECAR (hq_I 2026-09-05): callers grading a progs/NAME.icn against a
#       NAME.ref should pass "$PKG/progs/NAME.dat" (falling back to /dev/null if absent) -- the same
#       convention test_icon_arizona_suite.sh/test_icon_jcon_suite.sh already use, and the one
#       util_cut_icon_ipl_refs.sh's own run_isolated() now mints refs under; see its header.
#   ipl_isolation_baseline "$CORPUS_ROOT"    # BEFORE the first program runs
#   ipl_isolation_verify_clean "$CORPUS_ROOT"  # after the last one
#       belt-and-suspenders: confirms nothing in the tracked ipl progs/gprogs/procs/gprocs/incl/gincl
#       subtree CHANGED between the two calls (a newly minted untracked *.ref excepted). Prints a loud ⛔
#       to stderr, names what moved, and returns 1 if it did -- call it at the end of any script that
#       uses ipl_isolation_run, so a breach is caught by the harness itself rather than by the next
#       `git status` a human happens to run. Skipping the baseline call still gives a guard, comparing
#       against HEAD, and the refusal text says that is what it did.
# A caller's own EXIT trap must call `ipl_isolation_cleanup` (or `rm -rf "$IPL_ISO_TEMPLATE"` directly) --
# this file does not set a trap itself, so it never silently overrides one a caller already set.

ipl_isolation_init() {
  local pkg="$1"
  IPL_ISO_TEMPLATE="$(mktemp -d "${TMPDIR:-/tmp}/ipl_iso_template.XXXXXX")" || return 1
  local sub
  # A subdirectory the package does not ship is skipped, not a failure (the coo 2026-10-03): the loop's last test was the function's
  # status, so a package without gincl/ read "could not build IPL isolation template" and the board refused; only a failed copy refuses.
  for sub in progs gprogs procs gprocs incl gincl; do
    [ -d "$pkg/$sub" ] || continue
    cp -r "$pkg/$sub" "$IPL_ISO_TEMPLATE/$sub" || return 1
  done
  return 0
}

ipl_isolation_cleanup() { [ -n "${IPL_ISO_TEMPLATE:-}" ] && rm -rf "$IPL_ISO_TEMPLATE"; [ -n "${IPL_ISO_BASELINE:-}" ] && rm -f "$IPL_ISO_BASELINE"; return 0; }

# ⛔⭐ THE CWD SUBDIRECTORY IS A PARAMETER, defaulting to progs/ (hq_I 2026-09-06, CEO-316). ipl refs
# are no longer progs-only: gprogs/ now carries .ref files too, and this helper hardcoded BOTH the cwd
# and an ICONPATH with no gprogs entry. Left alone it would have run every gprogs entry from the wrong
# directory, with its own package subdirectory missing from the link path -- and, because the caller
# passes the .icn by its TRACKED absolute path, the self-mutation hazard this whole file exists to
# prevent would have been live again for exactly the programs it was not covering. Set IPL_ISO_SUBDIR
# to the entry's own subdirectory before calling; unset means progs/, which is the historical behavior
# byte for byte.
#       ⭐ NAME.fixtures/ FIXTURE-FILE SIDECAR (seat07 2026-09-06): set IPL_ISO_FIXTURES to a program's
#       .icn path before calling and any files under NAME.fixtures/ are staged into the run directory
#       before exec, same env-var-toggle shape as IPL_ISO_SUBDIR. Unset means no staging (unchanged
#       historical behavior). A malformed sidecar (see ipl_fixtures_stage below) returns 125, distinct
#       from every other sentinel this function already returns (124 timeout, 127 setup failure).
# ⛔⭐⭐ THE ISOLATED ENVIRONMENT IS STATED ONCE, HERE, AND PATH IS PART OF IT (hq_P 2026-09-10, on hq_R's
# routed ASK out of the parked qei row). Until now every caller wrote its own `env ICONPATH=... cmd` line and
# INHERITED EVERYTHING ELSE -- so the harness looked hermetic while controlling exactly one variable.
# ⛔ WHAT THAT COSTS, MEASURED ON progs/qei.icn, WHICH SHELLS OUT AT LINE 185 (`system("icont -s qei_.icn …")`
# then `system("qei_")`, both BARE NAMES resolved through PATH). Three stable outcomes, decided entirely by
# the PATH of whoever invoked the harness, and NOT ONE OF THEM ANNOUNCES ITSELF -- every one is a well-formed,
# non-empty, reproducible transcript:
#     PATH without the oracle bin      -> 111 bytes, `sh: 1: icont: not found` per expression
#     oracle bin, no '.' on PATH       -> 109 bytes, `sh: 1: qei_: not found`  per expression
#     oracle bin and '.' on PATH       -> 120 bytes, the real evaluation
# ⭐ THE DANGER IS THE SHAPE, NOT THE PROGRAM: `sh: 1: qei_: not found` reads as A DEFECT IN THE PROGRAM, so a
# ref cut under one PATH and graded under another is a SILENT FALSE FAIL, and it is silent in both directions.
# It also outlived its own evidence once already -- ALL.excluded.txt:731 records "oracle produced EMPTY output"
# for qei, which is FALSE (the oracle answers 59 bytes on empty stdin); that line was written from a failed run
# and survived the condition that produced it.
# ✅ WHY A SHARED DEFINITION AND NOT A PER-PROGRAM `NAME.path` SIDECAR (the alternative hq_R offered): PATH is
# not a property of qei. It is a hole in the isolation, identically open for all 108 run-graded entries, and a
# per-program file would RECORD the hole rather than close it -- while requiring the one thing nobody can
# supply in advance, namely which programs shell out. ⛔ AND THE LOAD-BEARING HALF IS THE SHARING, not the
# policy: util_cut_icon_ipl_refs.sh (the CUTTER, which mints the refs) built its own env line twice, so the
# minting environment and the grading environment were free to drift apart by ordinary editing, in a dimension
# neither of them named. Two instruments, one question, no mechanism keeping them honest.
# ⭐ ORDER IS DELIBERATE: the ORACLE BIN FIRST so `icont` is OUR Arizona icont and never another on the box;
# '.' LAST so a file the program writes into its own rundir cannot shadow a system binary (verified sufficient
# -- qei evaluates correctly with '.' last). A minimal /usr/bin:/bin between them rather than the caller's
# inherited PATH, so the environment is DECLARED rather than borrowed.
# ⛔ WHAT THIS DOES NOT DO, AND IT MATTERS TO ANY READER OF A qei ROW: a program that shells out to `icont` is
# answered by the ARIZONA COMPILER in both arms, ours and the oracle's. Proven by killswitch -- run qei under
# SCRIP with the oracle bin off PATH and `write(1+1);` answers `sh: 1: icont: not found` instead of 2. So such
# an entry grades system(), file writing and the driver loop; it would stay GREEN if our expression evaluation
# were entirely broken, and its agreement with the oracle is not evidence about the evaluator.
# ⛔⭐⭐ THE ENVIRONMENT IS STATED ONCE HERE, SO THIS FILE MUST OWN ALL OF IT -- INCLUDING THE HELPER IT
# READS THE ORACLE PATH FROM (hq_R 2026-09-11, measured on the qei row). The PATH clause above resolves the
# oracle bin through `icont_bin`, which lives in lib_oracle_flags.sh -- and this file never sourced it. A
# caller that had sourced lib_oracle_flags.sh got the oracle segment; a caller that had not got the clause
# SILENTLY DROPPED, because `command -v icont_bin` cannot tell "no oracle on this box" from "the helper was
# never loaded". ⛔ THE TWO ANSWERS ARE NOT EQUALLY WRONG: a missing oracle is a fact about the box, while an
# unloaded helper is a fact about the caller, and the second one is the common case here --
# test_icon_ipl_suite.sh, THE RUN-GRADED BOARD ITSELF, sources this lib and has never sourced
# lib_oracle_flags.sh, so every run-graded IPL entry was executed with the oracle OFF PATH while its .ref was
# cut with the oracle ON it. For the 108 entries that never resolve a name through PATH that is invisible;
# for progs/qei, which shells out to `icont` and to its own compiled `qei_`, it is a SILENT FALSE FAIL -- the
# graded run answers `sh: 1: icont: not found` in place of the evaluation, a well-formed 111-byte output that
# announces nothing and diffs against a correct ref. ⭐ THE SHAPE, which is why the cure is here and not in
# the runner: hq_P's own header for this clause says a missing oracle stays "loud (`icont: not found`) rather
# than wrong" -- and that reasoning holds only while that string reaches a HUMAN. Here it lands inside the
# graded program's own stdout, where loud and wrong are the same bytes. A diagnostic is only loud in a stream
# somebody reads as a diagnostic; routed into a compared stream it is indistinguishable from an answer.
# So: load the helper ourselves (it defines functions only -- no side effects, safe to re-source), and if the
# oracle is genuinely unavailable AFTER that, say so ONCE on stderr instead of letting the absence travel
# silently into 108 refs. The fallback itself is unchanged: the segment is still simply absent.
_ipl_iso_load_oracle_flags() {
  command -v icont_bin >/dev/null 2>&1 && return 0
  local _here; _here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  . "$_here/lib_oracle_flags.sh" 2>/dev/null || return 1
  command -v icont_bin >/dev/null 2>&1
}
ipl_isolation_env() {
  local work="$1" arr="$2" _ob=""
  _ipl_iso_load_oracle_flags || :
  # ⛔ `dirname "$(icont_bin)"` CANNOT EXPRESS "no oracle": on a box without one icont_bin prints its refusal
  # to STDERR, returns 1 and emits NOTHING on stdout -- and `dirname ""` is `.`, so the unguarded form put the
  # CURRENT WORKING DIRECTORY on PATH as though it were the oracle bin, and the absent-segment fallback the
  # comment above promises was unreachable. Take the value, then test it: a non-zero rc or an empty string is
  # the absence, and only a real directory becomes a PATH segment.
  local _ib=""
  if command -v icont_bin >/dev/null 2>&1; then _ib="$(icont_bin 2>/dev/null)" || _ib=""; fi
  [ -n "$_ib" ] && [ -d "$(dirname "$_ib")" ] && _ob="$(dirname "$_ib")"
  if [ -z "$_ob" ] && [ -z "${_IPL_ISO_NO_ORACLE_WARNED:-}" ]; then
    _IPL_ISO_NO_ORACLE_WARNED=1
    echo "⛔ ipl_isolation_env: NO ICON ORACLE BIN -- the PATH handed to every isolated run omits it, so a program that shells out to \`icont\` (progs/qei) answers \`icont: not found\` INSIDE its graded output and reads as a wrong answer, not as a missing tool. Refs cut elsewhere with the oracle on PATH will false-FAIL against this run." >&2
  fi
  eval "$arr=()"
  # ⛔ LIBRARIES BEFORE PROGRAMS (ceo ruling 2026-10-01 on hq_icon's ask): icont links the distribution's library ucode, where
  # only procs/gprocs live, so a `link gener` in a library means procs/gener.icn, never the progs/gener.icn program of the same
  # name. SCRIP's link search is flat (icn_link_open: IPATH, ICONPATH, ...), so the order of this path IS the answer; with
  # progs: first, procs/codeobj.icn's `link gener` reached progs/gener.icn and huffstuf died with error 106 through &null.
  eval "$arr+=(\"ICONPATH=\$work/procs:\$work/gprocs:\$work/progs:\$work/gprogs:\$work/incl:\$work/gincl\")"
  # ⛔ A MISSING ORACLE MUST NOT SILENTLY PRODUCE A PLAUSIBLE PATH. If icont_bin is unavailable the oracle
  # segment is simply absent, which reproduces outcome 1 above -- loud (`icont: not found`) rather than wrong.
  if [ -n "$_ob" ]; then eval "$arr+=(\"PATH=\$_ob:/usr/bin:/bin:.\")"; else eval "$arr+=(\"PATH=/usr/bin:/bin:.\")"; fi
}
ipl_isolation_run() {
  local outfile="$1" to="$2" stdin_src="$3" work rc sub; shift 3
  sub="${IPL_ISO_SUBDIR:-progs}"
  # ⛔⭐ REFUSE ON AN UNINITIALIZED TEMPLATE, and the reason is what the omission actually does. A caller that
  # forgets `ipl_isolation_init` leaves IPL_ISO_TEMPLATE empty, and the `cp -r "$IPL_ISO_TEMPLATE"/. "$work"/`
  # below then expands to `cp -r /. "$work"/` -- it walks the WHOLE FILESYSTEM into the scratch directory. Measured
  # 2026-09-06 by hq_I, who did exactly this while building a one-program repro harness: it ran for minutes
  # copying /dev, /swap.img and every mount before it was killed. ⭐ THE SHAPE IS THE LESSON: an unset variable
  # in a path prefix does not produce an error, it produces a DIFFERENT VALID PATH -- and for a leading path the
  # value it silently becomes is the root of the filesystem, so the failure mode of forgetting init is unbounded
  # work and a filled disk rather than a diagnostic. Guarded here, where the expansion happens, and NOT merely
  # documented in the header: the header already said `ipl_isolation_init` was required, and that is precisely
  # the instruction that failed to prevent it.
  [ -n "${IPL_ISO_TEMPLATE:-}" ] && [ -d "${IPL_ISO_TEMPLATE:-}" ] || { echo "⛔ ipl_isolation_run REFUSES(127): IPL_ISO_TEMPLATE is unset or not a directory -- call ipl_isolation_init \"\$PKG\" first (unset would make the copy below read the filesystem root)" >&2; return 127; }
  work="$(mktemp -d "${TMPDIR:-/tmp}/ipl_iso_run.XXXXXX")" || return 127
  cp -r "$IPL_ISO_TEMPLATE"/. "$work"/
  [ -d "$work/$sub" ] || { echo "⛔ ipl_isolation_run: no such package subdirectory: $sub" >&2; rm -rf "$work"; return 127; }
  local rd="$work/$sub" cap=""
  if [ -n "${IPL_ISO_FIXTURES:-}" ]; then
    ipl_alone_declared "$IPL_ISO_FIXTURES"; case $? in 0) rd="$work/.alone"; mkdir -p "$rd" ;; 2) rm -rf "$work"; return 125 ;; esac
    ipl_fixtures_stage "$IPL_ISO_FIXTURES" "$rd"; [ $? -eq 2 ] && { rm -rf "$work"; return 125; }
    ipl_mask_check "$IPL_ISO_FIXTURES" || { rm -rf "$work"; return 125; }
    cap="$(ipl_head_declared "$IPL_ISO_FIXTURES")" || { rm -rf "$work"; return 125; }
  fi
  local -a _isoenv=(); ipl_isolation_env "$work" _isoenv
  # ⛔ A DRIVER RUN LINKS THE LIBRARY SHIPPED BESIDE IT (CEO-1269; coo 2026-09-25, hq_icon's ask): ICONPATH above names progs/ first,
  # and IPL ships four basenames twice over, so a procs/ driver's `link NAME` could reach a progs/ namesake. IPL_ISO_DRIVER=1 puts
  # the driver's own isolated directory first on IPATH, which SCRIP and icont read before ICONPATH -- as the Arizona and Jcon runners
  # give a NAME_driver run (09ee9fb91). Any other program runs exactly as before.
  [ -n "${IPL_ISO_DRIVER:-}" ] && _isoenv+=("IPATH=$work/$sub")
  # ⭐ THE UNIT'S RUN SIDECARS (NAME.env, NAME.pin, NAME.shims/, NAME.pty, NAME.alone, NAME.head, NAME.outfiles), applied exactly as the cutter applies them.
  local -a _cmd=("$@")
  if [ -n "${IPL_ISO_FIXTURES:-}" ]; then
    ipl_env_apply "$IPL_ISO_FIXTURES" "$rd" _isoenv || { rm -rf "$work"; return 125; }
    ipl_pty_declared "$IPL_ISO_FIXTURES"; case $? in 0) ipl_pty_cmd _cmd "$@" ;; 2) rm -rf "$work"; return 125 ;; esac
  fi
  ipl_capped_run "$cap" "$rd" "$to" "$stdin_src" "$outfile" _isoenv "${_cmd[@]}"
  rc=$?
  if [ -n "${IPL_ISO_FIXTURES:-}" ]; then ipl_outfiles_append "$IPL_ISO_FIXTURES" "$rd" "$outfile" || { rm -rf "$work"; return 125; }; fi
  rm -rf "$work"
  return "$rc"
}

# ⛔⭐⭐ THIS ANSWERS "DID THE TREE CHANGE DURING THIS RUN", AND IT USED TO ANSWER "DOES THE TREE DIFFER
# FROM HEAD" -- two different questions, and the second one cries BREACH at work the package asked for
# (hq_I 2026-09-06, measured while authoring the CEO-328 argv fixtures). Ten new NAME.argv/NAME.in files
# sat untracked in progs/ before the cutter ever started; every run then ended with the triple-⛔ banner
# saying isolation was breached, over a run in which nothing was breached at all. ⭐ THE COST IS NOT THE
# FALSE LINE, IT IS WHAT A FALSE LINE TEACHES: this banner exists because a first cut of the ref-cutter
# renamed all 275 vendored sources to UPPERCASE in place, and a banner that fires on every fixture-
# authoring sitting is one nobody reads on the sitting it is finally right. So: SNAPSHOT FIRST, COMPARE
# AFTER. ipl_isolation_baseline records the subtree's porcelain state before any program runs; verify
# reports only what is NEW since then, whatever its extension.
# ⛔ WITH NO BASELINE the old HEAD comparison is kept -- a caller that never snapshotted still gets a
# guard -- but it SAYS SO in the refusal, because "you have untracked fixtures" and "a program rewrote
# the tree" must not print the same sentence.
# ⭐ The exemption narrowed while it moved: it was `grep -v '\.ref$'`, which exempted a .ref at ANY
# status -- including ` M` on a TRACKED ref, i.e. a pinned ref overwritten mid-run, the single most
# damaging thing that could happen here. Only an UNTRACKED NEW .ref (`?? …`, what --apply legitimately
# mints) is exempt now; the old form leaned on the separate `git diff --quiet` arm to catch that case.
_ipl_iso_state() {
  git -C "$1" status --porcelain -- packages/icon/ipl/progs packages/icon/ipl/gprogs packages/icon/ipl/procs packages/icon/ipl/gprocs packages/icon/ipl/incl packages/icon/ipl/gincl 2>/dev/null | LC_ALL=C sort
}
ipl_isolation_baseline() {
  IPL_ISO_BASELINE="$(mktemp "${TMPDIR:-/tmp}/ipl_iso_baseline.XXXXXX")" || return 1
  _ipl_iso_state "$1" > "$IPL_ISO_BASELINE"
}
ipl_isolation_verify_clean() {
  local corpus="$1" now changed scope
  now="$(mktemp "${TMPDIR:-/tmp}/ipl_iso_now.XXXXXX")" || return 1
  _ipl_iso_state "$corpus" > "$now"
  if [ -n "${IPL_ISO_BASELINE:-}" ] && [ -f "$IPL_ISO_BASELINE" ]; then
    changed="$(LC_ALL=C comm -13 "$IPL_ISO_BASELINE" "$now" | grep -v '^?? .*\.ref$')"
    scope="since this run's baseline"
  else
    changed="$(grep -v '^?? .*\.ref$' "$now")"
    scope="against HEAD -- NO BASELINE WAS CAPTURED, so a fixture that was already untracked before this run reads as a breach here; call ipl_isolation_baseline before the first program runs to get the real answer"
  fi
  rm -f "$now"; [ -n "${IPL_ISO_BASELINE:-}" ] && { rm -f "$IPL_ISO_BASELINE"; IPL_ISO_BASELINE=""; }
  [ -z "$changed" ] && return 0
  echo "⛔⛔⛔ THE TRACKED IPL TREE CHANGED DURING THIS RUN ($scope) -- isolation was breached, investigate before trusting anything above ⛔⛔⛔" >&2
  printf '%s\n' "$changed" | head -20 >&2
  return 1
}

# ⛔⭐⭐ THE ARGV SIDECAR, AND IT LIVES HERE FOR THE SAME REASON THE CWD RULE DOES (hq_I 2026-09-06,
# CEO-328 ruling: "one path-aware cutter that reads both sidecars ... never a fork of the cutter or the
# grader"). ipl already honours a NAME.dat stdin sidecar, looked up INDEPENDENTLY by the ref-cutter and
# by the suite -- two copies of one convention, which is exactly how test_prolog_ladder.sh and its Raku
# twin silently diverged until they were diffed. This reader is the single authority for the second
# sidecar, so a cutter that mints a ref and a grader that checks it cannot disagree about what argv the
# program was given. ⛔ PATH-AWARE, NEVER BASENAME: ipl ships gener/morse/repeats/spokes in two
# directories apiece, so the sidecar is resolved beside the .icn and nowhere else.
#
# FORMAT -- NAME.argv beside NAME.icn, ONE line: NAME<TAB>arg<TAB>arg...
#   The leading NAME column is REDUNDANT here (the filename already carries it) and is required anyway,
#   deliberately: it is hq_T's format for the suite-level <family>.argv byte for byte (SCRIP 44f9e17ce),
#   so nobody moving between the two has to remember which shape they are in -- and a copied sidecar
#   whose name column no longer matches its file is caught instead of silently arming the wrong program.
#   ⭐ NO QUOTING LANGUAGE AT ALL, exactly as hq_T argued: an argument containing spaces arrives byte for
#   byte because TAB is the only separator and there is no word-splitting layer to be misread through.
#
# ipl_argv_read <icn-path> <array-name>
#   0 -> a sidecar was read; the named array holds the declared argv (never empty on 0)
#   1 -> no sidecar beside that .icn; the array is emptied. NOT an error: most programs take no argv.
#   2 -> the sidecar exists and is MALFORMED. ⛔ Refuses loudly rather than running the program with a
#        guessed argv: a fixture that arms the wrong arguments prints plausible output and pins it.
ipl_argv_read() {
  local icn="$1" arr="$2" side base line n
  eval "$arr=()"
  side="${icn%.icn}.argv"
  base="$(basename "$icn" .icn)"
  [ -f "$side" ] || return 1
  n=$(grep -cv '^[[:space:]]*\(#.*\)\?$' "$side")
  if [ "$n" -ne 1 ]; then
    echo "⛔ ARGV SIDECAR REFUSES(2): $side holds $n declaration lines, expected exactly 1 -- one program, one argv" >&2; return 2
  fi
  line="$(grep -v '^[[:space:]]*\(#.*\)\?$' "$side" | head -1)"
  local IFS=$'\t'; local -a f=($line); unset IFS
  if [ "${f[0]}" != "$base" ]; then
    # ⛔ SAY WHICH OF THE TWO CONTRACTS THIS IS, because the same extension carries both and the refusal
    # above is unreadable when the file is fine and the READER is wrong (hq_V 2026-09-12, CEO-604).
    if [ -f "${icn%.icn}.csv" ]; then
      echo "⛔ ARGV SIDECAR REFUSES(2): $side is a SUITE CONTAINER's per-entry argv table (a $base.csv sits beside it), read by corpus_suite_harness.read_argv_sidecar and keyed on ENTRY names -- it names '$base' nowhere and never could. This reader is for ONE witness's argv. The file is not malformed; the caller pointed a witness reader at a container." >&2; return 2
    fi
    echo "⛔ ARGV SIDECAR REFUSES(2): $side declares '${f[0]}' but sits beside $base.icn -- a copied sidecar arming the wrong program" >&2; return 2
  fi
  if [ "${#f[@]}" -lt 2 ]; then
    echo "⛔ ARGV SIDECAR REFUSES(2): $side names $base and declares no arguments -- an empty argv is what you get with no sidecar at all, so the file states nothing" >&2; return 2
  fi
  eval "$arr=(\"\${f[@]:1}\")"
  return 0
}

# ⭐ NAME.fixtures/ FIXTURE-FILE SIDECAR (seat07 2026-09-06). NAME.dat covers stdin content and NAME.argv
# covers argument VALUES, but several ipl programs take an argument that NAMES A REAL FILE ON DISK --
# gediff.icn diffs two file arguments, huffstuf.icn/filecnvt.icn/iiencode.icn each read a named input file
# directly. Neither existing sidecar can place a file into the isolated run directory, so a NAME.argv
# naming "fixture.txt" is useless without something to put fixture.txt there. Same shape as ipl_argv_read:
# one shared reader, called by both the cutter's own run_isolated() and the shared ipl_isolation_run()
# above (via IPL_ISO_FIXTURES), so a program's minted ref and its later grading can never disagree about
# which files were present when it ran.
#
# FORMAT -- NAME.fixtures/ directory beside NAME.icn, holding one regular file per fixture, copied into
# the run directory verbatim BY ITS OWN FILENAME (never renamed); NAME.argv then names that same filename.
# No manifest: the directory's own contents ARE the declaration, same as NAME.dat's bytes ARE the stdin
# declaration with no format wrapped around them.
#
# ipl_fixtures_stage <icn-path> <dest-dir>
#   0 -> zero or more fixture files staged into dest-dir (0 is normal: most programs need none)
#   2 -> NAME.fixtures exists but is not a plain directory of regular files -- refuses loudly rather than
#        stage a symlink or subdirectory silently, which would either escape the scratch tree or leave the
#        program that needed it failing under the wrong reported class.
ipl_fixtures_stage() {
  local icn="$1" dest="$2" dir f
  dir="${icn%.icn}.fixtures"
  [ -e "$dir" ] || return 0
  if [ ! -d "$dir" ] || [ -L "$dir" ]; then
    echo "⛔ FIXTURE SIDECAR REFUSES(2): $dir exists but is not a plain directory" >&2; return 2
  fi
  # ⭐ SUBDIRECTORIES AND DOTFILES ARE STAGED (hq_icon 2026-09-27, ceo CEO-1315, Lon's "Get IPL to 843."): progs/iplweb and
  # progs/mszip take a directory TREE as their argument and progs/newsrc opens the fixed name .newsrc, and the old '*' glob copied
  # neither -- it skipped dotfiles and refused every subdirectory. The tree is copied as it stands; a symlink or a special file
  # anywhere in it still refuses, since either could escape the scratch tree. ⛔ A staged file is visible to every program that
  # lists its directory. progs/duplfile (ls -R) and progs/gcomp (echo *) therefore run ALONE over their own fixture trees (NAME.alone;
  # duplfile since ceo CEO-1516, when the 10-04 fixtures turned its ref stale), and any new unit that lists its cwd takes the same sidecar.
  f="$(find "$dir" -mindepth 1 \( -type l -o \( ! -type f ! -type d \) \) -print -quit)"
  [ -z "$f" ] || { echo "⛔ FIXTURE SIDECAR REFUSES(2): $f is not a plain regular file or directory" >&2; return 2; }
  cp -R "$dir"/. "$dest"/ || return 2
  return 0
}

# ⭐⭐ THE PER-UNIT RUN SIDECARS (hq_icon 2026-09-27; Lon's word "Get IPL to 843."; ceo CEO-1315: "The seven runner sidecars are
# YOURS ... Each is a per-test-unit attribute read by the one IPL reader (CEO-1281), with one gate per sidecar"). Each is a file
# beside NAME.icn, read here and applied by BOTH callers at the same point -- util_cut_icon_ipl_refs.sh's run_isolated (the ref)
# and ipl_isolation_run (m3 and m4) -- so a ref and its grading can never run in two different worlds. Absent means today's
# behaviour exactly; a malformed sidecar refuses (rc 2), never guesses.
#   NAME.env      KEY=VALUE per line (# comments): the unit's environment, e.g. TERM, TERMCAP, HOME=@RUNDIR (the run directory),
#                 VISUAL=cat. The runner's own variables (PATH IPATH ICONPATH LD_* SCRIP_*) are refused.
#   NAME.pin      the clock and entropy pin: an LD_PRELOAD shim (../harness/scripts/ipl_pin_shim.c) fixes the wall clock, zeroes CPU time and
#                 serves /dev/urandom from a fixed stream, wrapping iconx in the cutter and SCRIP in both modes alike.
#   NAME.rc       the program's correct exit status, one integer 0..255 on its only non-comment line (every exit is stop(): 1),
#                 read by ipl_rc_declared for the cutter (both of its comparisons), the runner and the sidecar gates -- one reader, so
#                 a comment line or a stray digit can never read as one status in one place and another, or none, in the next.
#   NAME.empty    one line of reason: the program's correct output is empty by design (proto exits first).
#   NAME.outfiles one relative path per line: files the program writes, appended to the graded output after the run.
#   NAME.pty      one line of reason: the unit runs on a pseudo-terminal (script(1)), for programs that need a terminal.
_ipl_side_lines() { grep -v '^[[:space:]]*\(#.*\)\?$' "$1"; }
# ipl_rc_declared <icn> -- echoes the exit status NAME.rc declares; echoes nothing when there is no NAME.rc; refuses (rc 2) anything
# but exactly one non-comment line holding one integer 0..255, so a malformed declaration can never be compared as a string or skipped.
ipl_rc_declared() {
  local side="${1%.icn}.rc" v
  [ -f "$side" ] || return 0
  v="$(_ipl_side_lines "$side")"
  if [ "$(printf '%s\n' "$v" | grep -c .)" -ne 1 ] || ! [[ "$v" =~ ^[[:space:]]*([0-9]{1,3})[[:space:]]*$ ]] || [ "$((10#${BASH_REMATCH[1]}))" -gt 255 ]; then
    echo "⛔ RC SIDECAR REFUSES(2): $side must hold one exit status 0..255 on its only non-comment line" >&2; return 2
  fi
  echo "$((10#${BASH_REMATCH[1]}))"
}
# ipl_env_apply <icn> <rundir> <arrname> -- appends the unit's NAME.env assignments (and NAME.pin's LD_PRELOAD) to an env array.
ipl_env_apply() {
  local icn="$1" run="$2" arr="$3" side kv k v so
  side="${icn%.icn}.env"
  if [ -f "$side" ]; then
    while IFS= read -r kv; do
      k="${kv%%=*}"; v="${kv#*=}"
      case "$kv" in *=*) ;; *) echo "⛔ ENV SIDECAR REFUSES(2): $side line [$kv] is not KEY=VALUE" >&2; return 2;; esac
      [[ "$k" =~ ^[A-Z_][A-Z0-9_]*$ ]] || { echo "⛔ ENV SIDECAR REFUSES(2): $side key [$k] is not an environment name" >&2; return 2; }
      case "$k" in PATH|IPATH|ICONPATH|LD_*|SCRIP_*) echo "⛔ ENV SIDECAR REFUSES(2): $side sets $k, which is the runner's to set, never a unit's" >&2; return 2;; esac
      v="${v//@RUNDIR/$run}"
      eval "$arr+=(\"\$k=\$v\")"
    done < <(_ipl_side_lines "$side")
  fi
  if [ -f "${icn%.icn}.pin" ]; then
    so="$(ipl_pin_shim_path)" || return 2
    eval "$arr+=(\"LD_PRELOAD=\$so\")"
  fi
  ipl_shims_apply "$icn" "$run" "$arr" || return 2
  return 0
}
# ipl_pin_shim_path -- echoes the built shim, compiling ../harness/scripts/ipl_pin_shim.c once per source hash into a cache directory.
ipl_pin_shim_path() {
  local src d h so
  src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ipl_pin_shim.c"
  [ -f "$src" ] || { echo "⛔ PIN SIDECAR REFUSES(2): $src is missing" >&2; return 2; }
  h="$(sha1sum "$src" | cut -c1-12)"; d="${TMPDIR:-/tmp}/scrip-ipl-pin-$(id -u)"; so="$d/pin-$h.so"
  mkdir -p -m 700 "$d" || { echo "⛔ PIN SIDECAR REFUSES(2): cannot create the shim cache $d" >&2; return 2; }
  if [ ! -O "$d" ] || { [ -f "$so" ] && [ ! -O "$so" ]; }; then
    echo "⛔ PIN SIDECAR REFUSES(2): the shim cache $d (or $so) belongs to another user -- a preloaded library is never trusted from a place someone else can write" >&2; return 2
  fi
  chmod 700 "$d" && { [ ! -f "$so" ] || chmod go-w "$so"; } || { echo "⛔ PIN SIDECAR REFUSES(2): cannot make the shim cache $d this user's alone" >&2; return 2; }
  if [ ! -f "$so" ]; then
    gcc -shared -fPIC -O0 -o "$so.tmp.$$" "$src" -ldl 2>"$d/build.err" && chmod go-w "$so.tmp.$$" && mv -f "$so.tmp.$$" "$so" \
      || { echo "⛔ PIN SIDECAR REFUSES(2): the pin shim did not build: $(head -c 200 "$d/build.err")" >&2; return 2; }
  fi
  echo "$so"
}
# ipl_empty_declared <icn> -- 0 when NAME.empty declares an empty output with a reason of 20+ characters, 1 when absent, 2 malformed.
ipl_empty_declared() {
  local side="${1%.icn}.empty" r
  [ -f "$side" ] || return 1
  r="$(_ipl_side_lines "$side")"
  [ "${#r}" -ge 20 ] || { echo "⛔ EMPTY SIDECAR REFUSES(2): $side must say WHY the output is empty by design (20+ characters)" >&2; return 2; }
  return 0
}
# ipl_outfiles_append <icn> <rundir> <outfile> -- appends each declared file the program wrote, in declaration order.
ipl_outfiles_append() {
  local side="${1%.icn}.outfiles" run="$2" out="$3" rel
  [ -f "$side" ] || return 0
  while IFS= read -r rel; do
    case "$rel" in /*|*..*) echo "⛔ OUTFILES SIDECAR REFUSES(2): $side names [$rel], which leaves the run directory" >&2; return 2;; esac
    printf '=== OUTFILE %s ===\n' "$rel" >> "$out"
    if [ -f "$run/$rel" ]; then cat "$run/$rel" >> "$out"; else printf '(absent)\n' >> "$out"; fi
  done < <(_ipl_side_lines "$side")
  return 0
}
# ipl_pty_declared <icn> -- 0 when NAME.pty asks for a pseudo-terminal (with a reason of 20+ characters), 1 absent, 2 malformed.
ipl_pty_declared() {
  local side="${1%.icn}.pty" r
  [ -f "$side" ] || return 1
  r="$(_ipl_side_lines "$side")"
  [ "${#r}" -ge 20 ] || { echo "⛔ PTY SIDECAR REFUSES(2): $side must say WHY the unit needs a terminal (20+ characters)" >&2; return 2; }
  return 0
}
# ipl_pty_cmd <arrname> cmd arg... -- sets the array to the command wrapped for script(1) when a terminal is declared.
ipl_pty_cmd() {
  local arr="$1"; shift; local q="" a
  for a in "$@"; do q="$q $(printf '%q' "$a")"; done
  eval "$arr=(script -qefc \"\${q# }\" /dev/null)"
}
# ⭐⭐ THE RUN- AND ENVIRONMENT-DEPENDENT UNITS RUN AND ARE GRADED (Lon CEO-1474, in-chat to hq_icon 2026-10-04, verbatim: "The answer is the test
# harness needs a mechanism for masking to allow these tests which are run-dependent, or environment dependent so that these tests can actually
# run and be graded."). Four more per-unit sidecars beside NAME.icn, read here and applied by the cutter and both modes alike:
#   NAME.mask     what varies with the run or the box: the CEO-409 rows (entry<TAB>python-regex-or-L<n><TAB>measured reason, ceo CEO-1504), read
#                 through util_apply_ceo409_mask.py on BOTH sides of every comparison; the ref on disk stays the oracle's raw output.
#   NAME.shims/   stand-in host commands (an MS-DOS dir, an ULTRIX ls, a fixed nm), put first on PATH for the unit's run alone.
#   NAME.alone    one line of reason: the unit runs in a directory of its own holding only its NAME.fixtures/ (a program that lists its cwd).
#   NAME.head     one integer: the run's output is cut at that many bytes and the cut ends the run (a program that never stops writing).
# ipl_mask_check <icn> -- 0 when there is no NAME.mask or the harness's own reader accepts it, 2 when it refuses (CEO-1504: the IPL mask IS the
# CEO-409 mask -- rows entry<TAB>python-regex-or-L<n><TAB>measured reason, read through util_apply_ceo409_mask.py, never a second masker).
ipl_mask_check() {
  local side="${1%.icn}.mask" c rc
  [ -f "$side" ] || return 0
  c="$(mktemp "${TMPDIR:-/tmp}/ipl_mask_n.XXXXXX")" || return 2
  python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_apply_ceo409_mask.py" "${1%.icn}.ref" "$(basename "${1%.icn}")" "$c" < /dev/null > /dev/null; rc=$?
  rm -f "$c" "$c.major"; [ "$rc" -eq 0 ] || return 2
}
# ipl_graded_cmp <icn> <got> <ref> [scrip|oracle] -- 0 when the two streams agree after the unit's CEO-409 rows mask both (a plain cmp without a
# NAME.mask). <got> is SCRIP's rendered output (the default) or a second oracle run (the cutter's determinism arms); <ref> is always the oracle's.
# A mask guardrail 4 rules a majority of either stream refuses (rc 2): a fixture mostly masked is ungradable, never graded (CEO-409, CEO-1504).
ipl_graded_cmp() {
  local side="${1%.icn}.mask" m e a b c rc
  [ -f "$side" ] || { cmp -s "$2" "$3"; return; }
  m="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_apply_ceo409_mask.py"; e="$(basename "${1%.icn}")"
  a="$(mktemp "${TMPDIR:-/tmp}/ipl_mask_a.XXXXXX")" && b="$(mktemp "${TMPDIR:-/tmp}/ipl_mask_b.XXXXXX")" && c="$(mktemp "${TMPDIR:-/tmp}/ipl_mask_n.XXXXXX")" || return 2
  rc=0
  python3 "$m" "${1%.icn}.ref" "$e" "$c" "--side=${4:-scrip}" < "$2" > "$a" || rc=2
  [ "$rc" -eq 0 ] && [ "$(cat "$c.major" 2>/dev/null)" = 1 ] && { echo "⛔ MASK SIDECAR REFUSES(2): $side masks a majority of $2 (guardrail 4)" >&2; rc=2; }
  [ "$rc" -eq 0 ] && { python3 "$m" "${1%.icn}.ref" "$e" "$c" --side=oracle < "$3" > "$b" || rc=2; }
  [ "$rc" -eq 0 ] && [ "$(cat "$c.major" 2>/dev/null)" = 1 ] && { echo "⛔ MASK SIDECAR REFUSES(2): $side masks a majority of $3 (guardrail 4)" >&2; rc=2; }
  [ "$rc" -eq 0 ] && { cmp -s "$a" "$b" || rc=1; }
  rm -f "$a" "$b" "$c" "$c.major"; return "$rc"
}
# ipl_shims_apply <icn> <rundir> <arrname> -- when NAME.shims/ exists, copies it beside the run directory and appends a PATH that puts it
# first ahead of the PATH the array already holds; refuses (2) a shim that is not a regular executable file.
ipl_shims_apply() {
  local src="${1%.icn}.shims" run="$2" arr="$3" dst p="" e f
  [ -d "$src" ] || return 0
  dst="$(dirname "$run")/.ipl_shims"; rm -rf "$dst"; mkdir -p "$dst" || return 2
  for f in "$src"/*; do
    [ -f "$f" ] || { echo "⛔ SHIMS SIDECAR REFUSES(2): $f is not a regular file" >&2; return 2; }
    [ -x "$f" ] || { echo "⛔ SHIMS SIDECAR REFUSES(2): $f is not executable -- a stand-in command must run (git add --chmod=+x)" >&2; return 2; }
    cp "$f" "$dst"/ || return 2
  done
  eval 'for e in "${'"$arr"'[@]}"; do case "$e" in PATH=*) p="${e#PATH=}";; esac; done'
  eval "$arr+=(\"PATH=\$dst:\$p\")"
}
# ipl_alone_declared <icn> -- 0 when NAME.alone asks for a run directory of its own (a reason of 20+ characters), 1 absent, 2 malformed.
ipl_alone_declared() {
  local side="${1%.icn}.alone" r
  [ -f "$side" ] || return 1
  r="$(_ipl_side_lines "$side")"
  [ "${#r}" -ge 20 ] || { echo "⛔ ALONE SIDECAR REFUSES(2): $side must say WHY the unit needs a directory of its own (20+ characters)" >&2; return 2; }
  return 0
}
# ipl_head_declared <icn> -- echoes the byte cap NAME.head declares (nothing when absent); refuses (2) anything but one integer 1..67108864.
ipl_head_declared() {
  local side="${1%.icn}.head" v
  [ -f "$side" ] || return 0
  v="$(_ipl_side_lines "$side")"
  if [ "$(printf '%s\n' "$v" | grep -c .)" -ne 1 ] || ! [[ "$v" =~ ^[[:space:]]*([0-9]{1,8})[[:space:]]*$ ]] || [ "$((10#${BASH_REMATCH[1]}))" -lt 1 ] || [ "$((10#${BASH_REMATCH[1]}))" -gt 67108864 ]; then
    echo "⛔ HEAD SIDECAR REFUSES(2): $side must hold one byte count 1..67108864 on its only non-comment line" >&2; return 2
  fi
  echo "$((10#${BASH_REMATCH[1]}))"
}
# ipl_capped_run <cap> <dir> <to> <stdin> <outfile> <envarr> cmd... -- runs cmd in dir with stdout+stderr to outfile; with a cap the output is
# cut at <cap> bytes and a run the cut ends (the program reached the cap) reads as status 0, so the cap is the run's declared end.
ipl_capped_run() {
  local cap="$1" dir="$2" to="$3" in="$4" out="$5" arr="$6" rc; shift 6
  local -a _e; eval '_e=("${'"$arr"'[@]}")'
  if [ -z "$cap" ]; then ( cd "$dir" && timeout -k 5 "$to" env "${_e[@]}" "$@" < "$in" > "$out" 2>&1 ); return; fi
  ( cd "$dir" && timeout -k 5 "$to" env "${_e[@]}" "$@" < "$in" 2>&1 | head -c "$cap" > "$out"; exit "${PIPESTATUS[0]}" ); rc=$?
  [ "$rc" -ne 124 ] && [ "$(wc -c < "$out")" -ge "$cap" ] && rc=0
  return "$rc"
}
