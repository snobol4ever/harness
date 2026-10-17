#!/usr/bin/env python3
"""util_gc_acceptance.py -- THE FOUR NUMBERS THE GC COMMITMENT IS MADE OF, computed, never typed.

Lon 2026-09-21, in-chat to the ceo, accepting the ceo's four definitions and ordering the display:
"Then we will commit to that. ... Can you display periodically the metrics which you are measuring
to state we made it 100%."  CEO-1039.  ARCH-GC-COMPILE-TIME-FRAME-MAPS.md section 11.

THE FOUR, each with a DENOMINATOR so the claim is falsifiable:
  1 INSTRUMENTED  every C->BB site hooked, every allocating call site polled, every callback wrapped.
  2 VISIBILITY    every event in the DECLARED event space observable and observed.
  3 AUDITED       every collection checked by the exact-vs-conservative differential pass, and its
                  SILENCE is the proof.  NOT 'every defect found' -- that is unprovable and the ceo
                  refused to promise it (the cfo's trap converts 2 of 17).
  4 WORKING       ZERO gradings lost to the collector across the arena and stress axes.  This is NOT
                  the rungs' absolute score: SnoRungs' 11 non-GC gaps are language completeness and
                  are frozen.  The target is that stress costs zero of them; today it costs 26+4 hangs.

INSTRUMENT LAW, held here rather than quoted: a metric that CANNOT BE MEASURED prints NOT-BUILT or
NOT-MEASURED and makes the verdict REFUSE(2).  It never prints 0 and never prints 100.  A display
that cannot tell 'clean' from 'never ran' is the thing this whole emergency is about.
"""
import os, re, subprocess, sys, datetime
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "SCRIP")

def sh(cmd, timeout=1800):
    try:
        p = subprocess.run(cmd, cwd=ROOT, shell=True, capture_output=True, text=True, timeout=timeout)
        return p.returncode, p.stdout + p.stderr
    except Exception as e:
        return 2, "REFUSE %s" % e

def num(pat, txt, default=None):
    m = re.search(pat, txt)
    return int(m.group(1)) if m else default

def pct(n, d):
    return "n/a" if not d else "%.1f%%" % (100.0 * n / d)

def reason_of(rc, txt, fallback):
    """⛔⭐ A SUB-INSTRUMENT'S rc=2 IS AUTHORITATIVE AND ITS REASON IS REPEATED VERBATIM (the coo, 2026-09-22).

    Three sub-instruments were invoked as `rc, out = sh(...)` and the rc was CAPTURED AND NEVER READ --
    the name was then reused by the next section, which is how it hid.  Two costs, both measured:

      1 THE WRONG CURE NAMED.  With a stale binary the census REFUSES(2) and prints no counts, and this
        display said "the census did not print a line this reader needs" -- an instrument-shape defect,
        sending the reader to edit util_gc_census.py when the actual cure is `make`.
      2 A REFUSED MEASUREMENT PRINTED AS A PERFECT SCORE.  util_gc_event_coverage.py returns 2 at two
        points AFTER its DENOMINATOR IDENTITY line is printed (no ratchet floor; unreadable gc_heap.c),
        so ex and obs parse, the rc is dropped, and item 2 reads `16 / 16  100.0%`.  This file's own
        docstring forbids exactly that: "It never prints 0 and never prints 100."

    A percentage is never printed over an rc=2.  The reason travels from the instrument that has it."""
    if rc != 2:
        return None
    for ln in txt.split("\n"):
        t = ln.strip()
        if "REFUSE" in t:
            return re.sub(r"^[\u26d4\u2b50\s]+", "", t)[:140]
    return fallback

def main():
    tree = sh("git rev-parse --short HEAD")[1].strip()
    corpus = sh("git -C ../corpus rev-parse --short HEAD")[1].strip()
    when = datetime.datetime.now().strftime("%Y-%m-%d %H:%M %Z")
    load = open("/proc/loadavg").read().split()[0]
    print("=" * 118)
    print("GC ACCEPTANCE -- the four numbers, computed (CEO-1039)   SCRIP %s . corpus %s . %s . load %s"
          % (tree, corpus, when, load))
    print("=" * 118)
    refuse, fails = [], []

    # ---- 1 INSTRUMENTED -------------------------------------------------------------------------
    rc_cen, cen = sh("SCRIP_GC_CENSUS_LIST_ALL=1 python3 ../harness/scripts/util_gc_census.py")
    polled   = num(r"allocating_call_sites=(\d+)", cen); pol_ok = num(r"\bpolled=(\d+)", cen)
    sp_part  = num(r"partially_polled=(\d+)", cen); sp_unp = num(r"\bunpolled=(\d+)", cen)
    inb      = num(r"INBOUND call_back_sites=(\d+)", cen); inb_w = num(r"INBOUND call_back_sites=\d+ wrapped_in_\w+=(\d+)", cen)
    outb     = num(r"OUTBOUND call_out_sites=(\d+)", cen); out_w = num(r"OUTBOUND call_out_sites=\d+ wrapped_in_\w+=(\d+)", cen)
    cons     = num(r"CENSUS conservative total=(\d+)", cen)
    c2bb_all = inb + outb if (inb is not None and outb is not None) else None
    # ⛔⭐ THE C->BB COVERAGE LINE IS NO LONGER COMPUTED HERE (ceo CEO-1091, on Lon's 2026-09-21 order to fix the
    # broken gauges).  It used to count rt_c2bb_hit occurrences in THREE NAMED FILES over the CALLBACK SITE count --
    # two different populations, with the 11 real hooks in rt/rt.c excluded by construction, so the fraction read
    # zero and meant nothing (CEO-1041/1071).  util_c2bb_coverage.py answers it against the denominator
    # test_gate_no_c_to_bb.sh itself prints, per site, by the proximity rule, and it is proven to fail once.
    rc_cov, cov = sh("python3 ../harness/scripts/util_c2bb_coverage.py")
    c2bb_cov_n = num(r"C2BB_COVERAGE hooked=(\d+)", cov)
    c2bb_cov_d = num(r"C2BB_COVERAGE hooked=\d+ sites=(\d+)", cov)
    cov_why = reason_of(rc_cov, cov, "util_c2bb_coverage.py exited 2 without naming a reason")
    c2bb_cov_refuse = (cov_why is not None) or ("REFUSE(2)" in cov) or (c2bb_cov_n is None) or (c2bb_cov_d is None)
    print("\n  1 INSTRUMENTED")
    cen_why = reason_of(rc_cen, cen, "util_gc_census.py exited 2 without naming a reason")
    if cen_why:
        refuse.append("INSTRUMENTED: the census REFUSED to measure -- %s" % cen_why)
        print("      REFUSE(2) -- the census refused, and its own reason is:")
        print("      %-46s %s" % ("", cen_why))
    elif None in (polled, pol_ok, inb, outb, cons):
        refuse.append("INSTRUMENTED: the census RAN (rc=%d) but printed no line this reader needs" % rc_cen)
        print("      REFUSE(2) -- census line missing (the census exited %d, so this IS an output-shape defect)" % rc_cen)
    else:
        marker_absent = "marker=RT_GC_CALLBACK defined_in_tree=NO" in cen
        rows = [("safe-point polls at allocating call returns", pol_ok, polled),
                ("callback wraps (RT_GC_CALLBACK)",             inb_w + out_w, c2bb_all),
                ("C->BB transfer sites carrying rt_c2bb_hit",  c2bb_cov_n, c2bb_cov_d)]
        for nm, n, d in rows:
            if nm.startswith("callback wraps") and marker_absent:
                print("      %-46s %s" % (nm, "REFUSE(2) -- THE WRAPPER DOES NOT EXIST"))
                print("      %-46s %s" % ("", "RT_GC_CALLBACK is not defined anywhere in the tree, so 0 of %d is NOT a" % (d or 0)))
                print("      %-46s %s" % ("", "backlog of %d wraps waiting to be written -- a wrap written today would" % (d or 0)))
                print("      %-46s %s" % ("", "not compile.  \u26d4 AND THE COMPONENT IS SATISFIABLE BY A NO-OP: a macro"))
                print("      %-46s %s" % ("", "defined as #define RT_GC_CALLBACK(x) x, applied to all %d sites, takes" % (d or 0)))
                print("      %-46s %s" % ("", "this line to 100% WITH NO SEMANTIC CHANGE WHATSOEVER.  A component of an"))
                print("      %-46s %s" % ("", "acceptance commitment that a no-op can satisfy is not a measurement, and"))
                print("      %-46s %s" % ("", "reporting it as '%d open' invited exactly that (CEO-1070)." % (d or 0)))
                print("      %-46s %s" % ("", "IT REFUSES UNTIL Rule 4 IS GIVEN A MEANING THE WRAPPER ENFORCES:"))
                print("      %-46s %s" % ("", "a runtime frame holds NO RAW HEAP POINTER across a callback into emitted"))
                print("      %-46s %s" % ("", "code.  Define that first, prove it fails once, then count sites."))
                refuse.append("INSTRUMENTED/callback: RT_GC_CALLBACK is undefined in the tree -- "
                              "0 of %d is unmeasurable, and a no-op macro would read 100%%" % (d or 0))
                continue
            if nm.startswith("C->BB"):
                if c2bb_cov_refuse:
                    why = cov_why or "util_c2bb_coverage.py printed no C2BB_COVERAGE line, so it did not measure"
                    print("      %-46s %s" % (nm, "REFUSE(2) -- %s" % why))
                    refuse.append("INSTRUMENTED/C->BB: %s" % why)
                    continue
                bad = (n < d)
                print("      %-46s %5d / %-5d  %-7s %s" % (nm, n, d, pct(n, d), "" if not bad else "<- %d dark" % (d - n)))
                for ln_ in cov.split("\n"):
                    if ln_.startswith("  UNHOOKED"): print("      %-46s %s" % ("", ln_.strip()))
                print("      %-46s %s" % ("", "denominator: the transfer sites test_gate_no_c_to_bb.sh itself names, not a"))
                print("      %-46s %s" % ("", "second grep -- forking that definition is what CEO-1071 caught. HOOKED is a"))
                print("      %-46s %s" % ("", "PROXIMITY test (a hit within 3 lines at or above the transfer): the earlier"))
                print("      %-46s %s" % ("", "function-body test was proven NOT to fail once and was replaced."))
                if bad: fails.append("INSTRUMENTED/C->BB %d of %d transfer sites hooked" % (n, d))
                continue
            bad = (n < d)
            print("      %-46s %5d / %-5d  %-7s %s" % (nm, n, d, pct(n, d), "" if not bad else "<- %d open" % (d - n)))
            # ⛔ THE OPEN COUNT IS TWO DIFFERENT DEBTS AND THEY TAKE DIFFERENT CURES (the coo, 2026-09-22).  An
            # UNPOLLED site has no safe point and needs one written.  A PARTIALLY POLLED site HAS one and it is
            # stepped over -- the jump emitted above the call, its landing pad below the poll -- so the cure is to
            # move the existing poll below the pad, and writing a second poll there would be the wrong repair.
            # Printing one number for both invites the wrong fix, which is why the split is stated here and not
            # left in the census's own output for a reader to go and find.
            if nm.startswith("safe-point") and bad and sp_part:
                print("      %-46s %s" % ("", "\u26d4 of those %d: %d UNPOLLED (no safe point) and %d PARTIALLY POLLED"
                                          % (d - n, sp_unp if sp_unp is not None else -1, sp_part)))
                print("      %-46s %s" % ("", "   (a poll IS emitted and a conditional jump steps over it -- cure is to"))
                print("      %-46s %s" % ("", "   MOVE the poll past the landing pad, never to add a second one)"))
            if nm.startswith("safe-point"):
                # ⛔⭐ WHAT THIS COMPONENT MEASURES, SAID IN ITS OWN OUTPUT (ceo CEO-1133, ruling two).  It was said
                # in rulings and ledgers while the display printed a bare percentage, and a reader who meets only
                # the percentage reads a claim nobody made.  A component that cannot tell a poll that FIRES from one
                # that never does must say so where the number is, not where the argument was.
                print("      %-46s %s" % ("", "\u26d4 THIS LINE MEASURES PRESENCE, NOT CORRECTNESS: it reads whether a"))
                print("      %-46s %s" % ("", "   poll is EMITTED at the site, never whether it FIRES, roots the right"))
                print("      %-46s %s" % ("", "   value, or is the right FORM.  100% here is necessary and NOT"))
                print("      %-46s %s" % ("", "   sufficient -- see the census's own POLL FORMS and UPPER BOUND lines."))
            if bad: fails.append("INSTRUMENTED/%s %d of %d" % (nm.split()[0], n, d))
        print("      %-46s %5d / %-5d  %-7s %s" % ("conservative visits deleted (want 0 remaining)", cons, 0, "100.0%" if cons == 0 else "n/a",
                                                   "" if cons == 0 else "<- %d remain" % cons))
        if cons: fails.append("INSTRUMENTED/conservative %d remain" % cons)

    # ---- 2 VISIBILITY ---------------------------------------------------------------------------
    rc_ev, ev = sh("python3 ../harness/scripts/util_gc_event_coverage.py")
    ex  = num(r"EXERCISED (\d+)", ev); obs = num(r"OBSERVABLE (\d+)", ev)
    owed = num(r"OWED -- real events this collector cannot distinguish \((\d+)\)", ev)
    print("\n  2 VISIBILITY")
    # ⛔ THE rc IS READ BEFORE THE NUMBERS ARE. util_gc_event_coverage.py returns 2 at two points AFTER
    # its identity line is printed, so ex and obs parse from a run that REFUSED TO MEASURE. Reading the
    # numbers first printed `16 / 16  100.0%` over it -- the one shape this file's docstring forbids.
    ev_why = reason_of(rc_ev, ev, "util_gc_event_coverage.py exited 2 without naming a reason")
    if ev_why:
        refuse.append("VISIBILITY: the event-coverage instrument REFUSED to measure -- %s" % ev_why)
        print("      REFUSE(2) -- the event-coverage instrument refused, and its own reason is:")
        print("      %-46s %s" % ("", ev_why))
        if None not in (ex, obs):
            print("      %-46s %s" % ("", "⛔ it printed EXERCISED %d / OBSERVABLE %d anyway -- NOT shown as a" % (ex, obs)))
            print("      %-46s %s" % ("", "   percentage: those counts are from a run that refused to measure."))
    elif None in (ex, obs):
        refuse.append("VISIBILITY: util_gc_event_coverage.py RAN (rc=%d) but printed no denominator identity" % rc_ev)
        print("      REFUSE(2) -- no denominator identity line (it exited %d, so this IS an output-shape defect)" % rc_ev)
    else:
        print("      %-46s %5d / %-5d  %-7s %s" % ("declared events observed", ex, obs, pct(ex, obs),
                                                   "" if ex == obs else "<- %d not exercised" % (obs - ex)))
        print("      %-46s %5d          %-7s %s" % ("events the collector CANNOT distinguish", owed or 0, "",
                                                    "" if not owed else "<- OWED, named not dropped"))
        if ex != obs: fails.append("VISIBILITY %d of %d exercised" % (ex, obs))
        if owed:      fails.append("VISIBILITY %d event(s) OWED -- unmeasurable, not merely unmeasured" % owed)

    # ---- 3 AUDITED ------------------------------------------------------------------------------
    _rc_grep, aud = sh("grep -rln 'gc_audit_pass_b\\|GC_AUDIT_PASS_B\\|SCRIP_GC_AUDIT_B' src/runtime || true")
    print("\n  3 AUDITED (every collection checked by the exact-vs-conservative differential; its SILENCE is the proof)")
    if not aud.strip():
        print("      NOT BUILT -- the pass-B auditor does not exist in src/runtime.  This metric REFUSES rather")
        print("                   than reading 0%: a display that cannot tell 'clean' from 'never ran' is the")
        print("                   defect this emergency is about.  Row is Lon's grant of 2026-09-21 with an expiry.")
        refuse.append("AUDITED: the pass-B auditor is not built, so collections-audited cannot be measured")
    else:
        print("      built in: %s" % aud.strip().replace("\n", ", "))

    # ---- 4 WORKING ------------------------------------------------------------------------------
    print("\n  4 WORKING (zero gradings lost to the collector -- NOT the rungs' absolute score)")
    print("      NOT MEASURED HERE BY DESIGN: this needs a board pass per language across the arena and")
    print("      stress axes, which is the one runner's job (MODE LANES), not a 20-second display's.")
    print("      \u26d4 THE LINES BELOW ARE TYPED, NOT COMPUTED, AND THEY ARE FROZEN AT THE 2026-09-21 STAND-DOWN.")
    print("         They are each lane's LAST SELF-REPORTED reading, tree named in that lane's baton, which is")
    print("         the authority -- NOT this display.  A typed figure in a computed dashboard is the defect this")
    print("         dashboard exists against, and hq_snobol4 caught this section quoting a number they had already")
    print("         WITHDRAWN (CEO-1052).  Under EXECUTIVE the six lanes are stood down and these cannot refresh")
    print("         themselves, so READ THE BATON before acting on any line here.")
    for lane, txt in (("RakRungs", "-65 gradings over 36 programs at stress 16; BOTH FAMILIES SINCE CURED by hq_raku, row closed 853/929 over three arms"),
                      ("SnoRungs", "CORRECTED BY ITS OWN LANE: a 19-entry reading with hang=0 crash=0, superseding the withdrawn -26-plus-4-hangs"),
                      ("IcnRungs", "-28 gradings; 27 of them REPRODUCE AT THE SHIPPED 512 MB ARENA (stress 16); 17 are every-driven generator resumption"),
                      ("SncRungs", "red at stress 1 alone across a sixteen-point band; the one entry SINCE CURED by the DT_X landing 83b8bc9d2"),
                      ("PasRungs", "LOWER BOUND CLEAN, empty name set at stress 4 and 16 -- its lane's own relabelling, never a clearance"),
                      ("ProRungs", "the exception ball SINCE CURED at CFO-119/5fc6ae1bc; its 74-pair population is UNMEASURED against the cure and is owed")):
        print("      %-6s %s" % (lane, txt))
    refuse.append("WORKING: no board pass on this tree -- the last readings are 2026-09-20 and the collector has moved")

    # ---- VERDICT --------------------------------------------------------------------------------
    print("\n" + "-" * 118)
    if refuse:
        print("  VERDICT: REFUSE(2) -- NOT AT 100%%, and %d of the four cannot even be measured today:" % len(refuse))
        for r in refuse: print("      ⛔ %s" % r)
        for f in fails:  print("      ✗  %s" % f)
        print("  ⛔ A REFUSE IS NOT A RED.  It says COULD NOT MEASURE.  Neither is it progress.")
        print("=" * 118); return 2
    if fails:
        print("  VERDICT: NOT YET -- every metric measured, %d short of 100%%:" % len(fails))
        for f in fails: print("      ✗  %s" % f)
        print("=" * 118); return 1
    print("  VERDICT: ✅ 100%% ON ALL FOUR -- instrumented, visible, audited, and zero gradings lost to the collector.")
    print("=" * 118); return 0

if __name__ == "__main__":
    sys.exit(main())
