#!/usr/bin/env python3
# util_precarve_whack_patches.py -- THE PRE-CARVE WHACK TABLE (ceo CEO-1940/1941; Lon 2026-10-24: "WHACK each pre-carve one at a time and see what breaks").
# One entry per site of .github/PRECARVE-WHACK-LIST.md: the exact source text of the carve (and its release where one exists) and what it becomes
# when whacked. Run from the SCRIP root: `python3 ../harness/scripts/util_precarve_whack_patches.py <site>` applies one whack in place (rc 0,
# prints FILES <touched>), `--list` names the sites and runs nothing. rc 3 NOPATCH when a required string is not in the tree (the site moved).
# A whack is a PROBE, never a landing: util_precarve_whack_probe.sh applies it, builds, tests, and restores the files with git checkout.
# site -> list of (file, old, new, required_min_count)
T = "src/templates/bb/"
P = {
 "06-glue_framed-fc_bytes": [(T+"bb_glue_framed.cpp", '         + x86("sub", "rsp", ((_.op_fc_bytes + 15) & ~15L));', '         + std::string();', 1),
                             (T+"bb_glue_framed.cpp", '    return x86("add", "rsp", ((_.op_fc_bytes + 15) & ~15L));', '    return std::string();', 1)],
 "07-glue_flat-fc_bytes":   [(T+"bb_glue_flat.cpp", '    return IF(_.op_fc_bytes > 0, x86("sub", "rsp", _.op_fc_bytes));', '    return std::string();', 1),
                             (T+"bb_glue_flat.cpp", '    return IF(_.op_fc_bytes > 0, x86("add", "rsp", _.op_fc_bytes));', '    return std::string();', 1)],
 "08-call_fn-CF_N-argblock": [(T+"bb_call_fn.cpp", '               emit_seq({ x86("sub", "rsp", (long)(CF_N() * 16)),', '               emit_seq({ std::string(),', 1),
                              (T+"bb_call_fn.cpp", '    return emit_seq({ IF(CF_N() > 0, x86("add", "rsp", (long)(CF_N() * 16))),', '    return emit_seq({ std::string(),', 1)],
 "09-call_fn-BCFN_EVAL_REC": [(T+"bb_call_fn.cpp", 'x86("sub", "rsp", (long)BCFN_EVAL_REC)', 'std::string()', 1),
                              (T+"bb_call_fn.cpp", 'x86("add", "rsp", (long)BCFN_EVAL_REC)', 'std::string()', 0)],
 "10-call_proc_staged-Kbz": [(T+"bb_call_proc_staged.cpp", 'x86("sub", "rsp", Kbz)', 'std::string()', 1), (T+"bb_call_proc_staged.cpp", 'x86("add", "rsp", Kbz)', 'std::string()', 0)],
 "11-call_proc_staged-Kb":  [(T+"bb_call_proc_staged.cpp", 'x86("sub", "rsp", Kb)', 'std::string()', 1), (T+"bb_call_proc_staged.cpp", 'x86("add", "rsp", Kb)', 'std::string()', 0)],
 "12-define-F4":            [(T+"bb_define.cpp", 'x86("sub", "rsp", F4)', 'std::string()', 1), (T+"bb_define.cpp", 'x86("add", "rsp", F4)', 'std::string()', 0)],
 "13-define-T4-argblock":   [(T+"bb_define.cpp", 'x86("sub", "rsp", T4 + 16L * nf4)', 'std::string()', 1), (T+"bb_define.cpp", 'x86("add", "rsp", T4 + 16L * nf4)', 'std::string()', 0)],
 "14-fence0_floor":         [(T+"bb_match_fence0.cpp", 'x86("sub", "rsp", (long)_.op_fence0_floor)', 'std::string()', 1), (T+"bb_match_fence0.cpp", 'x86("add", "rsp", (long)_.op_fence0_floor)', 'std::string()', 0),
                             (T+"bb_match_flush.cpp", 'x86("sub", "rsp", (long)_.op_fence0_floor)', 'std::string()', 1), (T+"bb_match_flush.cpp", 'x86("add", "rsp", (long)_.op_fence0_floor)', 'std::string()', 0)],
 "03-match_begin-frame_extra": [(T+"bb_match_begin.cpp", '(long)(24 + _.op_frame_extra)', '24L', 1)],
 "02-xa_flat-argkt":        [("src/templates/xa/xa_flat.cpp", 's += x86("sub", "rsp", (long)argkt)', 's += std::string()', 1), ("src/templates/xa/xa_flat.cpp", 'x86("add", "rsp", (long)argkt)', 'std::string()', 0)],
 "04-emit-blob_carve":      [("src/emitter/emit.cpp", 'x86("sub", "rsp", (long)(blob_carve_bytes() + blob_carve_pad()))', 'std::string()', 1)],
 "05-emit-sph":             [("src/emitter/emit.cpp", 'bb_emit_x86(x86("sub", "rsp", (long)_sph) +', 'bb_emit_x86(std::string() +', 1)],
 "15-x86_asm-zbgrow-at-beta": [("src/templates/x86/x86_asm.h", 's += x86("sub", "rsp", (long)_.op_zbgrow);', 's += std::string();', 1)],
}
import sys
if len(sys.argv) < 2 or sys.argv[1] in ("--list", "-l"):
    for k in P: print(k)
    sys.exit(0)
site = sys.argv[1]; files = set()
if site not in P: print("unknown site %s; --list names them" % site); sys.exit(2)
for f, old, new, mn in P[site]:
    b = open(f, "rb").read(); n = b.count(old.encode())
    if n < mn: print(f"NOPATCH {site} {f} count={n} need>={mn}"); sys.exit(3)
    if n: open(f, "wb").write(b.replace(old.encode(), new.encode())); files.add(f); print(f"patched {f} x{n}")
print("FILES " + " ".join(sorted(files)))
