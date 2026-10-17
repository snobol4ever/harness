#!/usr/bin/env python3
# Generate a REP-LOOP + BRACKETED variant of a -match demo. Aspect 2 of Lon's two-aspect law:
# the program itself brackets the FIXTURE (the match), so the match phase is isolated from the
# pattern-COMPILE phase that dominates these demos at their committed inputs.
# ⛔ REFUSES rather than emitting a variant it cannot vouch for: exactly one fixture line, or nothing.
import sys, re
src_path, out_path, brk_path, reps = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
lines = open(src_path, encoding='utf-8', errors='surrogateescape').read().split('\n')
# ⛔ THE FIXTURE IS FOUND BY ANCHORING ON THE SUBJECT, NOT ON A '?' -- SNOBOL4 HAS TWO MATCH SPELLINGS
# and these demos use BOTH. calculator-1/treebank/claws5 write the EXPLICIT form `src ? C :F(error)`;
# calculator-2 and json write the IMPLICIT juxtaposition form `src  C  :F(error)` with no '?' at all.
# A detector keyed on '?' finds zero fixtures in the second group and, if it then fell back to a guess,
# would silently bracket the wrong statement. So: locate `<subj> = INPUT`, then take the next
# non-comment statement whose subject is that same variable and which is NOT an assignment.
m = [(i, mm.group(1)) for i, l in enumerate(lines)
     if not l.startswith('*') for mm in [re.match(r'^\s+(\w+)\s*=\s*INPUT\b', l)] if mm]
if len(m) != 1:
    sys.stderr.write("REFUSE: found %d `<subj> = INPUT` lines in %s (want exactly 1); not guessing\n" % (len(m), src_path))
    sys.exit(2)
read_at, subj = m[0]
def stmt_part(l):
    j = l.find(':')            # strip the goto field before testing for an assignment
    return l if j < 0 else l[:j]
fix = [i for i in range(read_at + 1, len(lines))
       if not lines[i].startswith('*') and re.match(r'^\s+' + re.escape(subj) + r'\s+\S', lines[i])
       and '=' not in stmt_part(lines[i])]
if not fix:
    sys.stderr.write("REFUSE: no match statement on subject '%s' after its INPUT read in %s\n" % (subj, src_path))
    sys.exit(2)
fix = [fix[0]]
i = fix[0]
stmt = lines[i].strip()
# ⭐ THE BRACKET GOES TO STDERR (ceo ruling, 2026-08-28): the correctness anchor and the perf instrument
# never share a channel, so stdout stays byte-identical and every committed .ref is untouched.
# ⛔ THIS WAS A TEMP FILE UNTIL TONIGHT, and only because SCRIP silently discarded every write to an
# OUTPUT association on a file descriptor. hq_C cured that (SCRIP 69178c73) -- and the defect was WIDER
# than the fd2 symptom I routed: -f1 was silently discarded identically, because _io_parse_opts
# understood -fn perfectly and had exactly one caller, _INPUT_; the write side never called the parser.
# Verified in both modes on the cured build before this switch was made.
# ⛔ LABELLED TIME_ns, NOT cpu_ns OR elapsed_ns, DELIBERATELY: TIME() is measured to be NANOSECONDS in
# both engines (calibrated against an external clock, not taken from the manual's millisecond
# convention), but WHICH clock it is -- wall or cpu -- is NOT settled: every calibration run was
# compute-bound, so the two coincide and the test cannot separate them. Naming it for the primitive
# rather than for a quantity we have not proven keeps the claim the size of the evidence.
# ⛔⛔ THE ASSOCIATION IS CREATED *AFTER* THE TIMED REGION, AND THAT IS NOT TIDINESS -- IT IS THE
# DIFFERENCE BETWEEN MEASURING THE MATCH AND MEASURING THE INSTRUMENT. The bracket used to open its
# OUTPUT association BEFORE the loop, and an existing association makes EVERY variable assignment pay
# an I/O channel lookup: SNOBOL4 semantics say assigning to an associated variable writes to its file,
# so NV_SET_fn must consult the channel table on every store. MEASURED on json-match's match phase,
# 60,000 reps, m4 -O0: with the association open across the loop the profile was led by
# _io_chan_find_by_var at 18.35%, plus NV_SET_fn 5.07% and mon_name_is_internal 3.74%, and ZERO
# emitted match boxes appeared in the top ten. With the association removed those three vanish
# entirely and the profile is led by rt_name_save_push / rt_proc_find / rt_call_proc_descr.
# ⭐ SO THE INSTRUMENT WAS MANUFACTURING ITS OWN TOP COST CENTRE, and doing it WORST on exactly the
# demos that assign most inside the match -- i.e. non-uniformly across the board, which is the kind of
# contamination that does not cancel in a multiple. T0 needs no association, and the write happens
# after the loop has ended, so opening the channel afterwards costs the measurement nothing.
pre = ["        rep_count = %s" % reps,
       "        rep_index = 0",
       "        rep_t0 = TIME()"]
post = ["        rep_index = LT(rep_index, rep_count) rep_index + 1              :S(rep_loop)",
        "        rep_t1 = TIME()",
        "        OUTPUT(.rep_brk, 7, '[-f2]')",
        "        rep_brk = 'BRACKET TIME_ns=' (rep_t1 - rep_t0) ' reps=' rep_count"]
lines[i:i+1] = pre + ["rep_loop " + stmt] + post
open(out_path, 'w', encoding='utf-8', errors='surrogateescape').write('\n'.join(lines))
print("ok fixture_line=%d stmt=%s" % (i + 1, stmt))
