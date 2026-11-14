#!/usr/bin/env python3
"""propagate_seat_digests_cto_484.py [--apply] [--root=<seat>]... [--out=<dir>] -- EVERY SEAT'S CLAUDE.md IS GENERATED PER ROLE (Lon 2026-11-04 12:1x CST,
in-chat to the cto, verbatim: "Scan what the CLAUDE.md file has for each HQ and officer and craft a better one considering each role being different.";
cto CTO-484; it supersedes propagate_seat_digests_ceo_2071.py, whose one COMMON text gave every seat the same SOP, recipe and command table).
Six roles, each a different file: the officer in charge (cto: rulings, designs, custody), the operating officer (coo: the loop, the health check, the
queue, the wake rule), the general officers (cfo cao cqo: a lander on any language), the language lanes (one language's suites, oracle, manual, extension,
ladder), the layer seats (zetas runtime collector templates packages: shared code, all eight smokes, the regenerated tables) and the ports (dotnet jvm:
their own repo, S4E_ENGINE, the SPITBOL ref). A seat's file is its header, its identity block (SEATS below), then the parts its role names from
the digest/parts folder of the .github repo ({ext} and {lang} filled for a lane). Without --apply it prints each root's new size and whether it changes; with --apply it
writes the file (LF, UTF-8) and keeps the previous text beside it as CLAUDE.md.bak-2026-11-04-cto-484 (never overwritten once written); --out=<dir>
renders every seat into <dir>/<seat>/CLAUDE.md for grading without touching a root. Idempotent. The gates: test_gate_seat_digests_within_budget.sh,
test_gate_digest_matches_rules.sh.
THE THREE HOME REPOS (Lon 2026-11-13 19:4x CST, verbatim: "so time then for the complete re-write of the make and shell scripts and fleet system to use the THREE NEW
repos in /home folder to be maintained by GRADER."; row harness-every-seats-hooks-and-claude-md-name-the-three-home-repos): --settings also renders every root's hooks
(settings.json: the Stop banner and the inbox; settings.local.json: the session start and the skill gate) to run from --harness=<dir> (default /home/harness) with
S4E_HOME the root and S4E_SEAT the root's own S4E_SEAT, so a root that drops its harness and .github keeps its mail, its banner and its gate; every other key is
kept as it is. Without --apply it prints each file's unified diff; with --apply it writes it, the old text beside it as <file>.bak-2026-11-13-three-home-repos.
--homes=<dir> (default /home) names the parent of the claude_<seat> roots, so the proof runs on a scratch copy. A hook is a human's to install: Lon runs --apply.
"""
import difflib, json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
PARTS = os.path.join(HERE, "..", "digest", "parts")
BAK = "CLAUDE.md.bak-2026-11-05-bare-bones"
ROLE_PARTS = {
    "in-charge": ["LAW", "SOP-officer", "DESIGN", "RECIPE", "BUILD-any", "ARCH"],
    "operating": ["LAW", "SOP-operating", "RECIPE", "BUILD-any", "ARCH"],
    "officer":   ["LAW", "SOP-lander", "RECIPE", "BUILD-any", "ARCH"],
    "lane":      ["LAW", "SOP-lander", "RECIPE", "BUILD", "ARCH"],
    "layer":     ["LAW", "SOP-lander", "RECIPE", "SHARED-CODE", "BUILD-any", "ARCH"],
    "port":      ["LAW-port", "SOP-lander", "RECIPE-port", "BUILD-port", "BUS-port"],
    "worker":    ["LAW", "SOP-lander", "RECIPE", "BUILD-any", "ARCH"],
}
# seat -> (role, identity block); a lane also carries (lang, ext) for the BUILD part
SEATS = {
    "grader": ("grading", """## THIS ROOT IS THE GRADER SEAT (postoffice identity `grader`): THE GRADE RUNNER'S SEAT. THIS ROOT IS THE TREE THE TEST CYCLE SYNCS AND GRADES FROM EVERY LAP: NEVER EDIT, BUILD, COMMIT OR SYNC HERE; WORK ONLY IN A WORKTREE UNDER /tmp/s4e/grader (`s4e_worktree.sh`) AND LAND THROUGH `s4e_land.sh` (Lon 2026-11-11, QUARTET, CIO-122)
""", None),
    "cto": ("in-charge", """## THIS ROOT IS THE CTO SEAT (postoffice identity `cto`): THE OFFICER IN CHARGE AND THE FLEET'S DESIGNER
- Lon is the CEO; the cto runs the fleet with the coo (Lon 2026-10-31, CTO-469): design and law are this seat's half, operating and testing the coo's. The fleet's humming is priority one: a seat with no work, an overloaded box or a red nobody owns is this seat's to route before any row of its own.
- Every design, every DESIGN-PLAN, every placement ruling, the toughest jobs of any kind, and every shared red the coo escalates while a layer seat is stood down. GOAL-CTO.md is the cursor; every ruling is the next `CTO-NNNN` there, the same sitting.
- Skills: `/scrip-memory-model` and `/scrip-architecture` first; every language skill and layer skill as the question needs; `/design-plans` and `/fleet-bus` for the deliverables.
""", None),
    "coo": ("operating", """## THIS ROOT IS THE COO SEAT (postoffice identity `coo`): THE OPERATING OFFICER AND THE ONE TESTING OFFICER
- ⛔ THE JOB IS OPERATING (Lon 2026-11-04, verbatim: "you are meant to be the engine that drive the entire fleet. You find the regressions and deploy the fixes." / "monitor the background processes periodically and keep an eye on them. Then suggest changes that would improve the throughput."; GOAL-COO COO-459): the loop, the board, the queue, the assignments and the wake-ups are this seat's, every turn, unasked; a bottleneck is removed the same turn or put to Lon with its number and the exact change, then re-measured.
- TESTING: alone runs the suites, boards, the blocking set (`make test`, `run_blocking_set.sh`), the `.s` regeneration and the asm identity proof, and alone writes SUITE TABLE rows. The loop (`.scratch/verifier`: loop8, tier1, seatwatch) grades one program in both modes as a unit, up to four at once with one run slot free and declared heap+stack under 16 GB; requests first, then staleness; every row read within 24 h (`util_suite_table_freshness.py --hours 24`); tier 1 core reds go to the lane within the tick. GOAL-COO.md is the cursor.
- This root also holds `snobol4dotnet/` and `snobol4jvm/`, the two SNOBOL4 ports (`/ports`).
- Skills: `/suites-and-grading`, `/shared-box`, `/fleet-bus` first; the language of a red it routes.
""", None),
    "cfo": ("officer", """## THIS ROOT IS THE CFO SEAT (postoffice identity `cfo`): ONE OF FIVE EQUAL SEATS UNDER QUINTET (cio, coo, cto, grader, cfo), SEATED ON FABLE 5.2 HIGH; IT DESIGNS, CODES AND TESTS (Lon 2026-11-11, CIO-126)
- Suite rows to 100 by THE LANDING RECIPE in whatever language MODE line 2 names, and the reviews of collector visitors and typed heap kinds (the cfo reviews every new DESCR kind, `/pascal` reference § 9 R5). GOAL-CFO.md is the cursor.
- Skills: `/pascal` first, then the language of the row held; `/scrip-memory-model` for any frame or collector question. Manuals: `/home/resources/manuals/<lang>/`.
""", None),
    "cao": ("officer", """## THIS ROOT IS THE CAO SEAT (postoffice identity `cao`): A GENERAL OFFICER (Opus)
- The rows MODE line 2 names, by THE LANDING RECIPE; Prolog (the XSB package, tabling, call subsumption) has been its ground. GOAL-CAO.md is the cursor.
- Skills: `/prolog` and `/prolog-tabling` first, then the language of the row held. Manuals: `/home/resources/manuals/<lang>/`.
""", None),
    "cqo": ("officer", """## THIS ROOT IS THE CQO SEAT (postoffice identity `cqo`): A GENERAL OFFICER (Opus)
- Suite rows to 100 by THE LANDING RECIPE in whatever language MODE line 2 names (Prolog's SWI and Trealla suites, the consulted-clause record), and the machine-management rows CTO-478 assigned (cgroup weights and quotas, the job server). GOAL-CQO.md is the cursor.
- Skills: `/prolog` first (its dialect record and database rulings), `/shared-box` for the machine rows, then the language of the row held. Manuals: `/home/resources/manuals/<lang>/`.
""", None),
    "cio": ("officer", """## THIS ROOT IS THE CIO SEAT (postoffice identity `cio`): THE CHIEF INFRASTRUCTURE OFFICER
- The fleet system itself, as DESIGN-PLAN box-scheduler lays it out (`/shared-box` § 8, `harness/designs/box_scheduler/STEPS.tsv`, `test_design_box_scheduler_steps.sh --list`): the bus (`s4e_msg.sh`: rows that close, retire and escalate themselves, one verb per ruling, RESUME, claim notices by touched paths, a done that holds no lock, the recut verb), the records (MODE capped with its archive, batons capped, the RULES index and the redirect map, a ruling found by its number), the landing (one landing command, generated tables merged by regeneration), hygiene (a background handle, a seat kills only its own, runners' outputs under /tmp), the wake by hook. Not the grader (the coo), the instruments and the box budget (the cqo), the gates (the cao), the box controller (the coo). GOAL-CIO.md is the cursor; Lon's escalation law (CTO-498) binds this seat: a row it cannot finish goes to the cto the same sitting.
- Skills: `/fleet-bus` first, `/design-plans` and `/shared-box`, `/gates-and-witnesses` before any test or DONE-WHEN edit; a language skill only for a witness.
""", None),
    "president": ("officer", """## THIS ROOT IS THE PRESIDENT SEAT (postoffice identity `president`): A SONNET 5.5 XHIGH SEAT (Lon 2026-11-05 15:2x CST: "The names will be simply PRESIDENT, VICE-PRESIDENT, SECRETARY, and MANAGER. They will be SOnnet 5.5 xhigh.")
- The middle rung of Lon's ladder (MODE 2026-11-05 14:1x: the officers, Fable 5.1, design the whole thing first in small chunks; a step Haiku cannot land climbs Haiku to Sonnet to Opus to Fable 5): this seat works ONLY a row an officer ASSIGNS it, exactly as the step is written in the row's baton NEXT, one landing per step, and sends a step it cannot land back to the designing officer by telegram with the measurement, never patched around. Its business beyond that is Lon's to name; until he does it mints nothing and claims no FREE row.
- Skills: the skill the row's gate names before the first edit; `/fleet-bus` for the bus; `/gates-and-witnesses` before any test or DONE-WHEN edit. Escalation: to the designing officer first, the cio for a fleet-system matter.
""", None),
    "vice_president": ("officer", """## THIS ROOT IS THE VICE-PRESIDENT SEAT (postoffice identity `vice_president`): A SONNET 5.5 XHIGH SEAT (Lon 2026-11-05 15:2x CST: "The names will be simply PRESIDENT, VICE-PRESIDENT, SECRETARY, and MANAGER. They will be SOnnet 5.5 xhigh.")
- The middle rung of Lon's ladder (MODE 2026-11-05 14:1x: the officers, Fable 5.1, design the whole thing first in small chunks; a step Haiku cannot land climbs Haiku to Sonnet to Opus to Fable 5): this seat works ONLY a row an officer ASSIGNS it, exactly as the step is written in the row's baton NEXT, one landing per step, and sends a step it cannot land back to the designing officer by telegram with the measurement, never patched around. Its business beyond that is Lon's to name; until he does it mints nothing and claims no FREE row.
- Skills: the skill the row's gate names before the first edit; `/fleet-bus` for the bus; `/gates-and-witnesses` before any test or DONE-WHEN edit. Escalation: to the designing officer first, the cio for a fleet-system matter.
""", None),
    "secretary": ("officer", """## THIS ROOT IS THE SECRETARY SEAT (postoffice identity `secretary`): A SONNET 5.5 XHIGH SEAT (Lon 2026-11-05 15:2x CST: "The names will be simply PRESIDENT, VICE-PRESIDENT, SECRETARY, and MANAGER. They will be SOnnet 5.5 xhigh.")
- The middle rung of Lon's ladder (MODE 2026-11-05 14:1x: the officers, Fable 5.1, design the whole thing first in small chunks; a step Haiku cannot land climbs Haiku to Sonnet to Opus to Fable 5): this seat works ONLY a row an officer ASSIGNS it, exactly as the step is written in the row's baton NEXT, one landing per step, and sends a step it cannot land back to the designing officer by telegram with the measurement, never patched around. Its business beyond that is Lon's to name; until he does it mints nothing and claims no FREE row.
- Skills: the skill the row's gate names before the first edit; `/fleet-bus` for the bus; `/gates-and-witnesses` before any test or DONE-WHEN edit. Escalation: to the designing officer first, the cio for a fleet-system matter.
""", None),
    "manager": ("officer", """## THIS ROOT IS THE MANAGER SEAT (postoffice identity `manager`): A SONNET 5.5 XHIGH SEAT (Lon 2026-11-05 15:2x CST: "The names will be simply PRESIDENT, VICE-PRESIDENT, SECRETARY, and MANAGER. They will be SOnnet 5.5 xhigh.")
- The middle rung of Lon's ladder (MODE 2026-11-05 14:1x: the officers, Fable 5.1, design the whole thing first in small chunks; a step Haiku cannot land climbs Haiku to Sonnet to Opus to Fable 5): this seat works ONLY a row an officer ASSIGNS it, exactly as the step is written in the row's baton NEXT, one landing per step, and sends a step it cannot land back to the designing officer by telegram with the measurement, never patched around. Its business beyond that is Lon's to name; until he does it mints nothing and claims no FREE row.
- Skills: the skill the row's gate names before the first edit; `/fleet-bus` for the bus; `/gates-and-witnesses` before any test or DONE-WHEN edit. Escalation: to the designing officer first, the cio for a fleet-system matter.
""", None),
    "zetas": ("layer", """## THIS ROOT IS THE hq_zetas SEAT (postoffice identity `hq_zetas`): THE PLANNER AND THE THREE ZETAS
- `src/planner/` and the plan table the emitter reads: placement decided once in the planner, the flat-cell rule, the frame layout, `test_gate_no_rsp_reset_at_beta.sh` at 0, `util_placement_watch.sh show`; the zeta-layout and planner-finish DESIGN-PLANs (`/scrip-memory-model` § DESIGN); every zsm-, zetas- and planner- row; every shared planner or emitter red a language seat names. GOAL-HQ-ZETAS.md is the cursor.
- Skills: `/scrip-memory-model` first, `/box-templates` when a template reads the plan, the language of the program that showed the red. Manuals: `/home/resources/manuals/` for the language's semantics, `byrd-boxes/` for the machine.
""", None),
    "runtime": ("layer", """## THIS ROOT IS THE hq_runtime SEAT (postoffice identity `hq_runtime`): THE SHARED RUNTIME
- `src/runtime/rt/ core/ builtins/ rtx/`: the C roads out of the boxes (a road returns an address and the box jumps; no C function enters a box), the builtin table and the call protocol (`/runtime-calls`, its builtin-table and error-protocol DESIGN-PLANs), the rtx asm leaves (`/rtx-asm-leaves`), the Prolog engine's trail and unifier (`/prolog-engine`). GOAL-HQ-RUNTIME.md is the cursor.
- Skills: `/runtime-calls` and `/scrip-memory-model` first, then the language of the row held. Manuals: `/home/resources/manuals/<lang>/` for a builtin's semantics.
""", None),
    "collector": ("layer", """## THIS ROOT IS THE hq_collector SEAT (postoffice identity `hq_collector`): THE COLLECTOR
- `src/runtime/rt/gc_*`, `rtx_gc.s`, `rtx_alloc.s` (`/gc-collector`, the frozen design): compile-time frame maps, typed visitors, the chain over the maps, the gc gates (`test_gate_gc_*`), the gc witnesses CSV, the stress and flip plants, `gc_allocating_table.inc` regenerated never edited. THE COLLECTOR GUESSES NOTHING. A collector red named by any seat (a red only under `SCRIP_GC_STRESS`) is this seat's within the tick. GOAL-HQ-COLLECTOR.md is the cursor.
- Skills: `/gc-collector` and `/scrip-memory-model` first. Manuals: `/home/resources/manuals/gc/`.
""", None),
    "templates": ("layer", """## THIS ROOT IS THE hq_templates SEAT (postoffice identity `hq_templates`): THE BOX TEMPLATES
- `src/templates/bb/` and the `x86()` encoder (`/box-templates`): every Byrd box's four ports as straight-line jumps, one return, no locals, one `x86()` call per line; `box_cell_shapes.inc` from `harness/scripts/box_cell_shapes.tsv`; the template audit; the runtime entry table (zeta-layout step 5). Under the split role this seat verifies and lands the cto's template steps. GOAL-HQ-TEMPLATES.md is the cursor.
- Skills: `/box-templates` and `/scrip-memory-model` first. Manuals: `/home/resources/manuals/byrd-boxes/`.
""", None),
    "packages": ("layer", """## THIS ROOT IS THE hq_packages SEAT (postoffice identity `hq_packages`): THE VENDORED SUITES
- `corpus/packages/<lang>/`: the vendored suites, their runners `test_<lang>_<pkg>_suite.sh`, their EXCLUDED and CONTAINERS lists, their oracle-cut refs; `install_*` scripts fetch an upstream drop into `/home/resources`. A package's oracle is one, named in its runner through the accessors in `lib_oracle_flags.sh`, never a bare name; a program the oracle cannot answer is excluded, never debt. GOAL-HQ-PACKAGES.md is the cursor.
- Skills: `/suites-and-grading` and `/gates-and-witnesses` first, then the language of the package. Manuals: `/home/resources/manuals/<lang>/`.
""", None),
    "dotnet": ("port", """## THIS ROOT IS THE hq_dotnet SEAT (postoffice identity `hq_dotnet`): THE .NET PORT
- `snobol4dotnet/` (C#) is its repo, a sibling in this root; its rows are `<suite>@dotnet` under `S4E_ENGINE=dotnet`, graded by the fleet's runners against the same SPITBOL refs as SCRIP; speed by instruction count against `sbl`. SNOBOL4 is its language. GOAL-HQ-DOTNET.md is the cursor. Stood down while SCRIP climbs to 100; its rows stay in place.
- Skills: `/ports` and `/snobol4`.
""", None),
    "jvm": ("port", """## THIS ROOT IS THE hq_jvm SEAT (postoffice identity `hq_jvm`): THE JVM PORT
- `snobol4jvm/` (Clojure) is its repo, a sibling in this root; its rows are `<suite>@jvm` under `S4E_ENGINE=jvm` for SNOBOL4, Snocone and Rebus, graded by the fleet's runners against the same refs as SCRIP. GOAL-HQ-JVM.md is the cursor. Stood down while SCRIP climbs to 100; its rows stay in place.
- Skills: `/ports` and `/snobol4`.
""", None),
}
LANES = {
    # seat: (title, suites, goal, oracle line, manual dir, skills, lang, ext)
    "snobol4": ("THE SNOBOL4 LANE", "SnoRungs Gimpel Flake Budne AIS TPgm X32T X64T Dotnet SnoDemo SnoBench", "GOAL-SNOBOL4-100.md",
                "SPITBOL, `/home/resources/x64/bin/sbl -bf` through `sbl_correctness_bin()`; its exit codes and compile-time folding are the ref's", "snobol4",
                "`/snobol4` first (reference § 8-11), `/rtx-asm-leaves` for a match leaf", "snobol4", "sno"),
    "snocone": ("THE SNOCONE AND REBUS LANE", "SncRungs SncDemo SncBench RebRungs RebBench, and the seven bootstrap parsers in `SCRIP/bootstrap/`", "GOAL-SNOCONE-100.md (and GOAL-PARSER-SC-TRANSPILE.md)",
                "SPITBOL, `/home/resources/x64/bin/sbl -bf` through `sbl_correctness_bin()` (Snocone and Rebus are SNOBOL4 in another syntax)", "snobol4",
                "`/snocone-parser-patterns` first (a bootstrap parser is one Snocone pattern), `/snobol4` § 10", "snocone", "sc"),
    "icon": ("THE ICON LANE", "IcnRungs IcnDemo IcnBench IPL Jcon Zona", "GOAL-ICON-100.md",
             "Arizona Icon 9.5.25a, `/home/resources/icon-master/bin/icont` through `icont_bin()`; semicolons are settled law", "icon",
             "`/icon` first (reference § 8-9), `/rtx-asm-leaves` for a generator leaf", "icon", "icn"),
    "unicon": ("THE UNICON LANE (the Icon superset: one front end with hq_icon's, no switch; a class, package, import or method header marks a Unicon program)", "UniTests (Unicon's own tests, refs cut through `unicon_bin()`); the Icon suites stay at 100 and are hq_icon's", "GOAL-UNICON-100.md",
               "Unicon through `unicon_bin()`; Icon's `icont_bin()` for what both share", "icon",
               "`/unicon` first (the markers, the class and package model, the pattern type, UniTests, the rungs), then `/icon`", "icon", "icn"),
    "prolog": ("THE PROLOG LANE", "ProRungs INRIA GNU-source Logtalk SWI TreallaTests XsbTests ProPuzzles ProRosetta ProDemo ProBench", "GOAL-PROLOG-100.md",
               "the program's own dialect decides: swipl 9.0.4 (`swipl_bin()`), GNU Prolog 1.6.0 (`gprolog_bin()`, `gplc_bin()`), XSB 5.0.0 (`xsb_bin()`, the xsb_tests package only); a Prolog witness is graded against swipl run once", "prolog",
               "`/prolog` first, then `/prolog-engine`, `/prolog-tabling` or `/prolog-constraints` as the row's machine", "prolog", "pl"),
    "pascal": ("THE PASCAL LANE", "PasRungs PAT FPC PasRosetta PasDemo PasBench", "GOAL-PASCAL-100.md",
               "Free Pascal 3.2.2, `fpc -Miso` through `fpc_bin()` (FPC, ObjFPC and Delphi dialects by the program's own markers)", "pascal",
               "`/pascal` first (reference § 8-9: the dialect record, the pruned tree, the front-end plan)", "pascal", "pas"),
    "raku": ("THE RAKU LANE (Raku climbs the rung ladder; the roast is the spec)", "RakRungs Roast RakDemo RakBench", "GOAL-RAKU-100.md",
             "rakudo 2026.05 through `rakudo_bin()` (the `raku` on PATH is 2022.12 and is not the oracle)", "raku",
             "`/raku` first (reference § 8-9: the rung ladder, the rewrite)", "raku", "raku"),
}
for seat, (title, suites, goal, oracle, man, skills, lang, ext) in LANES.items():
    SEATS[seat] = ("lane", f"""## THIS ROOT IS THE hq_{seat} SEAT (postoffice identity `hq_{seat}`): {title}
- Its suites to 100 percent, one program at a time by THE LANDING RECIPE: {suites}. The lane's state is the LIVE CURSOR of `{goal}`; `LANES:` in MODE admits the runner; a shared-code red (runtime, collector, planner, templates) goes by bus to hq_runtime, hq_collector, hq_zetas or hq_templates.
- The oracle: {oracle}. Preflight `ls` it: a missing oracle prints a plausible all-FAIL table. A ref is cut from the oracle through its accessor, never a bare path; what the oracle cannot answer is excluded, never debt. The manual is text under `/home/resources/manuals/{man}/`, read before any ruling on a builtin or a syntax.
- Skills: {skills}; `/scrip-memory-model` for any frame, placement or collector question; `/gates-and-witnesses` before writing a test.
""", (lang, ext))
for _n in range(1, 21):
    _seat = "junior_%02d" % _n
    SEATS[_seat] = ("worker", """## THIS ROOT IS SEAT %s (postoffice identity `%s`): A HAIKU JUNIOR, ONE OF TWENTY (junior_01 to junior_20; named worker_NN until Lon 2026-11-08 06:4x: "rename WORKER to be JUNIOR to match the SENIOR") (Lon 2026-11-05 15:1x CST: "rename them all 01, 02, ..., 20." / 15:4x: "So use worker_00 and worker_01. Add the underscaore." / "Start from 01 not 00. Because there are no longer any specialties seats. We have skills now instead use by ANY ASSIGNED seat.")
- No specialty and no lane: this seat works ONLY a row an officer or a company man ASSIGNS it (MODE 2026-11-05 16:4x, the ladder: design flows Fable to Opus to Sonnet to Haiku, work climbs back), exactly as the step is written in the row's baton NEXT, one landing per step; it loads the skills the row's files need (the skill gate names them before the first edit; the language skill of the program it touches; `/gates-and-witnesses` before any test or DONE-WHEN edit); it mints nothing, claims no FREE row, and the dispatcher hands it none.
- A step it cannot land after one honest try goes back by telegram to the seat that assigned it, with the measurement (the command, the output, the tree hash), never patched around; a fleet-system matter goes to the cio. Its cursor is the row's baton: NEXT rewritten and LEDGER written before it stops.
""" % (_seat.upper(), _seat), None)
for _n in range(1, 9):
    _seat = "officer_%02d" % _n
    SEATS[_seat] = ("officer", """## THIS ROOT IS SEAT %s (postoffice identity `%s`): AN OPUS DESIGNER, ONE OF EIGHT (officer_01 to officer_08; 06 to 08 were cfo, cao and cqo until Lon 2026-11-07 17:1x: "I rename everything") (Lon 2026-11-07 15:4x CST, in the cio's window: "the OFFICERS can design as well"; "many officers as many as you need do DESIGN and maybe ask for quick review to CTO/CIO"; the cio's proportions 15:5x: 8 Opus designers for 2125 reds)
- A general officer of rung 2 with no fixed language: it DESIGNS, cause by cause, the suite reds the cto's design or the queue hands it, cutting each cause into rows under THE HAIKU BAR (skill `fleet-bus` section 1) that start at `tier-haiku`; it takes the rung-2 escalations `next` serves it from `tier-opus`; a design it is unsure of goes to the cto (SCRIP) or the cio (the fleet) by `ask`, never by chat.
- Skills: `/fleet-bus` first, `/design-plans` for a stepped design, `/gates-and-witnesses` before any DONE-WHEN, then the language skill of the reds it designs (`/raku`, `/prolog`, `/icon`, `/unicon`, `/pascal`, `/snobol4`). Manuals: `/home/resources/manuals/<lang>/`.
""" % (_seat.upper(), _seat), None)
for _n in range(1, 13):   # senior_09 to 12 had no CLAUDE.md: the range stopped at 08 (the coo 2026-11-13 20:5x CST; the seat folders under /home are the roster's source)
    _seat = "senior_%02d" % _n
    SEATS[_seat] = ("officer", """## THIS ROOT IS SEAT %s (postoffice identity `%s`): A SONNET 5.5 SENIOR, ONE OF TWELVE (senior_01 to senior_12; 05 to 08 were the president, vice_president, secretary and manager until Lon 2026-11-07 17:1x) (Lon 2026-11-07 15:4x CST: "Then MANY Sonnet work after escalation from the 20 Haiku workers"; the cio's proportions 15:5x: 8 Sonnet seniors beside the four company men)
- The middle rung of THE LADDER (skill `fleet-bus` section 1): this seat works ONLY the job `next` serves it from `tier-sonnet` or `seat-<me>`, a worker's escalation, exactly as the step is written in the row's baton NEXT, one landing per step; it starts no task of its own and mints nothing. A step it cannot land after one honest try it escalates with the measurement (`escalate <topic> --stdin`) to `tier-opus`; a fleet-system matter goes to the cio.
- Skills: the skill the row's gate names before the first edit; `/fleet-bus` for the bus; `/gates-and-witnesses` before any test or DONE-WHEN edit.
""" % (_seat.upper(), _seat), None)
HEADER = """# CLAUDE.md

Seat `/home/claude_{seat}` of the snobol4ever fleet. BARE BONES on Lon's word (2026-11-05: "the CLAUDE.md file is almost useless so STRIP it down to BARE BONES. No specific knowledge. All that goes in SKILLS."): this file names the seat and points; every fact and every law lives in a skill, the record in MODE and the batons. GENERATED by `/home/harness/scripts/propagate_seat_digests_cto_484.py`; never edit one root by hand.

"""
BODY = """
- THE LAW is the skills (`.claude/skills/`, from `/home/.github/skills/`); anything anywhere contradicting a skill is void. A ruling's lasting idea lives in the skill it governs (the GOAL files are deleted); MODE (`head -2 /home/resources/postoffice/MODE` and its keyed lines) is the record of who is who; Lon is the CEO and his word is the go.
- THE SITTING and THE LANDING RECIPE are skill `fleet-bus` section 7, and the seat's own conduct is skill `seat-conduct`; load both first. A row ASSIGNED to you is the go; a worker takes no FREE row.
- THE SKILLS carry every fact (`.claude/skills/`), thirty of them, and the skill gate refuses an edit until the skill that owns the file is loaded. THE FLEET: `fleet-bus` (first), `seat-conduct`, `gates-and-witnesses` (before any test or DONE-WHEN edit), `design-plans`, `shared-box`, `suites-and-grading`, `speed-measurement`, `fleet-ops-industry`. THE MACHINE: `scrip-architecture` (first when a task crosses layers), `byrd-boxes` (the model and every layout: before any box, any lowering of control, any Prolog engine work), `scrip-c-code`, `scrip-build`, `scrip-memory-model`, `gc-collector`, `runtime-calls`, `box-templates`, `rtx-asm-leaves`, `lowering`, `snocone-parser-patterns`, `scrip-backends`. THE LANGUAGES: `snobol4`, `icon`, `unicon`, `prolog`, `prolog-engine`, `prolog-tabling`, `prolog-constraints`, `pascal`, `raku`, `ports`.
- THE RECORD, never the chat: a ruling with a lasting idea lands in the skill it governs, on origin, the same sitting; what you did goes in the baton's LEDGER; a step you cannot land goes back by telegram with the measurement, never patched around.
"""
def render(seat):
    role, ident, le = SEATS[seat]
    head = ident.split("\n", 1)[0].rstrip() + "\n"
    return HEADER.format(seat=seat) + head + BODY
SBAK = ".bak-2026-11-13-three-home-repos"
HOOKS = {   # file -> event -> (the script that marks our hook, matcher or None, timeout, statusMessage or None, the command for (harness scripts dir, root, seat))
    "settings.json": {
        "Stop": ("s4e_banner_cached.sh", None, 120, "Firing {seat} banner",
                 'h={h}; d={d}; if [ -f "$h/s4e_banner_cached.sh" ]; then S4E_HOME="$d" S4E_SEAT={seat} bash "$h/s4e_banner_cached.sh" "$d" {seat}; else printf \'{{"systemMessage":"no banner: %s/s4e_banner_cached.sh is missing"}}\\n\' "$h"; fi'),
        "UserPromptSubmit": ("s4e_inbox_hook.sh", None, 30, "Checking {seat} inbox",
                 'out=$(S4E_HOME={d} S4E_SEAT={seat} timeout 20 bash {h}/s4e_inbox_hook.sh 2>&1); printf \'%s\' "$out" | python3 -c \'import json,sys; print(json.dumps({{"hookSpecificOutput":{{"hookEventName":"UserPromptSubmit","additionalContext":sys.stdin.read()}}}}))\''),
    },
    "settings.local.json": {
        "SessionStart": ("s4e_session_start.sh", None, 10, None, 'S4E_HOME={d} S4E_SEAT={seat} bash {h}/s4e_session_start.sh 2>/dev/null || true'),
        "PreToolUse": ("s4e_skill_gate.py", "Edit|Write|MultiEdit|NotebookEdit|Bash", 10, None, 'test -f {h}/s4e_skill_gate.py && S4E_HOME={d} S4E_SEAT={seat} python3 -I {h}/s4e_skill_gate.py'),
    },
}
def render_settings(root, harness):
    """-> [(path, old text, new text)] for the root's two settings files; REFUSE(2) on a file that is not JSON or a root with no S4E_SEAT."""
    texts, docs = {}, {}
    for f in HOOKS:
        p = os.path.join(root, ".claude", f); t = open(p, encoding="utf-8").read() if os.path.exists(p) else ""
        try: docs[f] = json.loads(t) if t.strip() else {}
        except Exception as e: sys.exit("REFUSE(2): %s is not JSON: %s" % (p, e))
        texts[f] = t
    seat = docs["settings.local.json"].get("env", {}).get("S4E_SEAT")
    if not seat: sys.exit("REFUSE(2): %s/.claude/settings.local.json names no S4E_SEAT" % root)
    h = os.path.join(harness, "scripts"); out = []
    for f, evs in HOOKS.items():
        d = docs[f]; hooks = d.setdefault("hooks", {})
        for ev, (mark, matcher, tmo, msg, cmd) in evs.items():
            h1 = {"type": "command", "command": cmd.format(h=h, d=root, seat=seat), "timeout": tmo}
            if msg: h1["statusMessage"] = msg.format(seat=seat)
            groups = [g for g in hooks.get(ev, []) if not any(mark in x.get("command", "") for x in g.get("hooks", []))]
            g1 = {"matcher": matcher, "hooks": [h1]} if matcher else {"hooks": [h1]}
            hooks[ev] = groups + [g1]
        new = json.dumps(d, indent=2, ensure_ascii=False) + "\n"
        out.append((os.path.join(root, ".claude", f), texts[f], new))
    return out
def settings_main(argv, apply):
    homes = ([a.split("=", 1)[1] for a in argv if a.startswith("--homes=")] or ["/home"])[0]
    harness = ([a.split("=", 1)[1] for a in argv if a.startswith("--harness=")] or ["/home/harness"])[0]
    only = [a.split("=", 1)[1] for a in argv if a.startswith("--root=")]
    if not os.path.isfile(os.path.join(harness, "scripts", "s4e_banner_cached.sh")): sys.exit("REFUSE(2): %s/scripts has no s4e_banner_cached.sh" % harness)
    roots = sorted(os.path.join(homes, n) for n in os.listdir(homes) if n.startswith("claude_") and os.path.isfile(os.path.join(homes, n, ".claude", "settings.local.json")))
    if only: roots = [r for r in roots if os.path.basename(r)[len("claude_"):] in only]
    todo = 0
    for root in roots:
        for p, old, new in render_settings(root, harness):
            if old == new: print("same  %s" % p); continue
            todo += 1
            if not apply:
                sys.stdout.writelines(difflib.unified_diff(old.splitlines(True), new.splitlines(True), p + " (now)", p + " (new)")); continue
            if old and not os.path.exists(p + SBAK):
                with open(p + SBAK, "w", encoding="utf-8", newline="\n") as fh: fh.write(old)
            with open(p + ".tmp", "w", encoding="utf-8", newline="\n") as fh: fh.write(new)
            os.replace(p + ".tmp", p); print("WROTE %s" % p)
    print("SEAT_SETTINGS %s=%d roots=%d harness=%s" % ("written" if apply else "to-write", todo, len(roots), harness))
def main(argv):
    apply = "--apply" in argv
    if "--settings" in argv: settings_main(argv, apply)
    out = [a.split("=", 1)[1] for a in argv if a.startswith("--out=")]
    only = [a.split("=", 1)[1] for a in argv if a.startswith("--root=")]
    seats = only or sorted(SEATS)
    changed = 0; towrite = 0
    for seat in seats:
        new = render(seat)
        if out:
            d = os.path.join(out[0], seat); os.makedirs(d, exist_ok=True)
            with open(os.path.join(d, "CLAUDE.md"), "w", encoding="utf-8", newline="\n") as fh: fh.write(new)
            print("%-5s %-10s %6d bytes -> %s" % ("out", seat, len(new.encode()), os.path.join(d, "CLAUDE.md"))); continue
        root = os.path.join(([a.split("=", 1)[1] for a in argv if a.startswith("--homes=")] or ["/home"])[0], "claude_%s" % seat)
        p = os.path.join(root, "CLAUDE.md")
        if not os.path.isdir(root):
            print("SKIP %-10s no root" % seat); continue
        old = open(p, encoding="utf-8").read() if os.path.exists(p) else ""
        same = old == new
        if not same: towrite += 1
        print("%-5s %-10s %6d bytes (was %6d) %s" % ("same" if same else ("WRITE" if apply else "would"), seat, len(new.encode()), len(old.encode()), "" if same else "-> " + p))
        if same or not apply:
            continue
        bak = os.path.join(root, BAK)
        if old and not os.path.exists(bak):
            with open(bak, "w", encoding="utf-8", newline="\n") as fh: fh.write(old)
        with open(p, "w", encoding="utf-8", newline="\n") as fh: fh.write(new)
        changed += 1
    if not out:
        print("SEAT_DIGESTS %s=%d of %d" % ("written" if apply else "to-write", changed if apply else towrite, len(seats)))
if __name__ == "__main__":
    main(sys.argv[1:])
