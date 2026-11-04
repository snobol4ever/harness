#!/usr/bin/env python3
"""s4e_skill_gate.py -- THE SKILL GATE (the cto, 2026-11-01; Lon in the cto's window: "Ensure the skills are described properly so that each seat
will use them ... I haven't noticed any use the skills specific to coding within SCRIP"). MEASURED before it: in the day since the skills were
installed (CEO-2071) the language skills were loaded 30 times across the seats and the coding skills (scrip-c-code, lowering, box-templates,
rtx-asm-leaves, gates-and-witnesses, snocone-parser-patterns) 19 times, seven seats loading none; the digests named only the language skills
and scrip-memory-model, and a description keyed on file names never fires at prompt time. THE GATE: a PreToolUse hook in every root
(util_fleet_settings.sh writes it; matcher Edit|Write|MultiEdit|NotebookEdit|Bash). It reads Claude Code's hook JSON on stdin (tool_name,
tool_input, transcript_path), maps the file the tool would write to the skills that own it (THE SKILL TABLE in the digest), reads the session's
transcript for the Skill calls made so far, and exits 2 with the skills still to load when one is missing; the seat loads them (one Skill call
each) and the same edit then passes. A Bash command is read for write intent (sed -i, perl -pi, > or >> or tee into a path, cp or mv onto a path,
a python open(path, 'w'|'a')) on a mapped path; a read of a mapped path is not refused. A generated table (gc_allocating_table.inc,
box_cell_shapes.inc, the rtx clobber table) is refused outright: regenerated, never edited. No transcript to read: the edit passes with a note
(a gate that cannot measure must not stall a seat). --self-test runs the fixtures (rc 0 all as expected, 1 otherwise); that is the test gate's body.
"""
import json, os, re, sys, tempfile

LANG = {"snobol4": "snobol4", "snocone": "snobol4", "rebus": "snobol4", "icon": "icon", "unicon": "unicon", "prolog": "prolog", "pascal": "pascal", "raku": "raku"}
GENERATED = ("gc_allocating_table.inc", "box_cell_shapes.inc", "rtx_clobber_table.inc", "rtx_clobbers.inc")
RULES = [   # (regex on the path, skills) -- every matching rule applies; the path is normalised to forward slashes
    (r"/SCRIP/src/templates/", ["box-templates"]),
    (r"/SCRIP/src/[^/]*/x86_[^/]*\.(h|cpp)$|/SCRIP/src/emitter/emit\.cpp$", ["box-templates"]),
    (r"/SCRIP/src/runtime/rtx/", ["rtx-asm-leaves"]),
    (r"/SCRIP/src/lower/", ["lowering"]),
    (r"/SCRIP/src/(planner|emitter)/|/SCRIP/src/runtime/rt/gc_", ["scrip-memory-model"]),
    (r"/SCRIP/bootstrap/[^/]*\.sc$", ["snocone-parser-patterns"]),
    (r"/SCRIP/src/runtime/rt/gc_|/SCRIP/src/runtime/rtx/rtx_(gc|alloc)\.s$", ["gc-collector"]),
    (r"/SCRIP/src/runtime/rt/rt\.c$|/SCRIP/src/lower/lower_call_forms\.c$|/harness/scripts/builtins\.tsv$", ["runtime-calls"]),
    (r"/SCRIP/Makefile$", ["scrip-build"]),
    (r"/SCRIP/src/lower/lower_icon_class\.c$|/corpus/tests/icon/unicon/|/corpus/packages/icon/unicon_tests/|/\.github/GOAL-UNICON-100\.md$|/harness/scripts/[^/]*unicon[^/]*$", ["unicon"]),
    (r"/harness/scripts/test_[^/]*\.sh$|/corpus/(tests|packages|demos|benchmarks)/.*(\.ref|/ALL\.csv|/STEPS\.tsv|/LADDER\.tsv)$|/corpus/tests/.*\.(sno|icn|pl|pas|raku|sc|reb)$", ["gates-and-witnesses"]),
]
WRITE_MARK = re.compile(r"(?:>>?|\btee\b(?:\s+-a)?|\bcp\b(?:\s+-[a-zA-Z]+)*(?:\s+\S+)|\bmv\b(?:\s+-[a-zA-Z]+)*(?:\s+\S+))\s+(?P<path>[\w./~-]+)")
INPLACE = re.compile(r"(?:\bsed\s+(?:-[a-zA-Z]*\s+)*-i[^\s]*|\bperl\s+-[a-zA-Z]*i[^\s]*)\s+(?P<rest>[^|;&]*)")   # the path is any later token of the same command
PY_OPEN = re.compile(r"open\(\s*['\"](?P<path>[^'\"]+)['\"]\s*,\s*['\"][wa][^'\"]*['\"]")


def skills_for(path):
    p = path.replace("\\", "/")
    if not p.startswith("/"):
        p = "/" + p
    if any(p.endswith("/" + g) for g in GENERATED):
        return None
    need = []
    for rx, sk in RULES:
        if re.search(rx, p):
            need += sk
    m = re.search(r"/SCRIP/src/parsers/([a-z0-9]+)/|/SCRIP/src/lower/lower_([a-z0-9]+)|/SCRIP/src/runtime/[^/]*/(?:prelude|lib)_?([a-z0-9]+)|/corpus/(?:tests|packages|demos|benchmarks)/([a-z0-9]+)/", p)
    if m:
        lang = next((g for g in m.groups() if g), "")
        if lang in LANG:
            need.append(LANG[lang])
    if re.search(r"/SCRIP/src/.*\.(c|h|inc)$", p) and "/SCRIP/src/parsers/" not in p:
        need.append("scrip-c-code")
    out = []
    for s in need:
        if s not in out:
            out.append(s)
    return out


def paths_of(tool, inp):
    if tool in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
        p = inp.get("file_path") or inp.get("notebook_path") or ""
        return [p] if p else []
    if tool == "Bash":
        cmd = inp.get("command", "")
        found = [m.group("path") for m in WRITE_MARK.finditer(cmd)] + [m.group("path") for m in PY_OPEN.finditer(cmd)]
        for m in INPLACE.finditer(cmd):
            found += [tok for tok in re.findall(r"[\w./~-]+", m.group("rest")) if "/" in tok]
        return [p for p in found if re.search(r"SCRIP/|/src/|bootstrap/|harness/scripts/|corpus/", p)]
    return []


def loaded(transcript):
    have = set()
    try:
        with open(transcript, "rb") as fh:
            for line in fh:
                if b"Skill" not in line and b"command-name" not in line:
                    continue
                s = line.decode("utf-8", "replace")
                for m in re.finditer(r'"name":\s*"Skill",\s*"input":\s*\{[^}]*"skill":\s*"([^"]+)"', s):
                    have.add(m.group(1).split(":")[-1])
                for m in re.finditer(r"<command-name>/([a-z0-9-]+)</command-name>", s):
                    have.add(m.group(1))
    except OSError:
        return None
    return have


def judge(tool, inp, transcript):
    """(rc, message): 0 pass, 2 refuse."""
    paths = paths_of(tool, inp)
    if not paths:
        return 0, ""
    gen = [p for p in paths if skills_for(p) is None]
    if gen:
        return 2, "SKILL GATE: %s is a GENERATED table, regenerated and never edited (make regenerates it; CLAUDE.md THE LANDING RECIPE 2)." % os.path.basename(gen[0])
    need = []
    for p in paths:
        for s in skills_for(p):
            if s not in need:
                need.append(s)
    if not need:
        return 0, ""
    have = loaded(transcript) if transcript else None
    if have is None:
        return 0, "skill gate: no transcript to read at %r; %s passes unread (load %s)" % (transcript, os.path.basename(paths[0]), ", ".join("/" + s for s in need))
    missing = [s for s in need if s not in have]
    if not missing:
        return 0, ""
    return 2, ("SKILL GATE: before this edit of %s load %s (one Skill call each: %s), then make the same edit again. "
               "The skill carries the rules the edit must keep; CLAUDE.md THE SKILL TABLE names which skill owns which layer."
               % (", ".join(os.path.basename(p) for p in paths), ", ".join("/" + s for s in missing), ", ".join("Skill(%s)" % s for s in missing)))


def self_test():
    d = tempfile.mkdtemp(prefix="s4e-skill-gate.")
    none = os.path.join(d, "none.jsonl"); open(none, "w").write('{"type":"user","message":{"role":"user","content":"hi"}}\n')
    some = os.path.join(d, "some.jsonl")
    with open(some, "w") as fh:
        for s in ("lowering", "prolog", "scrip-c-code", "box-templates"):
            fh.write('{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Skill","input":{"skill":"%s"}}]}}\n' % s)
        fh.write('{"type":"user","message":{"role":"user","content":"<command-name>/gates-and-witnesses</command-name>"}}\n')
    R = "/home/claude_x"
    cases = [
        ("Edit of a Prolog lowerer with no skill loaded refuses, naming lowering, prolog and scrip-c-code", "Edit", {"file_path": R + "/SCRIP/src/lower/lower_prolog.c"}, none, 2, ["/lowering", "/prolog", "/scrip-c-code"]),
        ("the same edit with the three loaded passes", "Edit", {"file_path": R + "/SCRIP/src/lower/lower_prolog.c"}, some, 0, []),
        ("Write of a new gate without gates-and-witnesses refuses", "Write", {"file_path": R + "/harness/scripts/test_gate_new_thing.sh"}, none, 2, ["/gates-and-witnesses"]),
        ("the same Write passes when the skill was typed as /gates-and-witnesses", "Write", {"file_path": R + "/harness/scripts/test_gate_new_thing.sh"}, some, 0, []),
        ("Edit of a README passes with nothing loaded", "Edit", {"file_path": R + "/.github/README.md"}, none, 0, []),
        ("Bash sed -i on a template without box-templates refuses", "Bash", {"command": "sed -i 's/a/b/' " + R + "/SCRIP/src/templates/bb/bb_pat_any.cpp"}, none, 2, ["/box-templates"]),
        ("Bash grep of a lowerer redirected to /tmp is a read and passes", "Bash", {"command": "grep -n x " + R + "/SCRIP/src/lower/lower_icon.c > /tmp/o.txt"}, none, 0, []),
        ("Bash python heredoc opening a planner file for writing refuses, naming scrip-memory-model and scrip-c-code", "Bash", {"command": "python3 - <<'PY'\nopen('" + R + "/SCRIP/src/planner/planner.c','w').write('x')\nPY"}, none, 2, ["/scrip-memory-model", "/scrip-c-code"]),
        ("Edit of a generated parser's C wants only the language skill", "Edit", {"file_path": R + "/SCRIP/src/parsers/icon/icon_parse.c"}, none, 2, ["/icon"]),
        ("Edit of a generated table refuses outright", "Edit", {"file_path": R + "/SCRIP/src/runtime/rt/gc_allocating_table.inc"}, some, 2, ["GENERATED"]),
        ("Edit of an rtx leaf wants rtx-asm-leaves (not scrip-c-code: a .s)", "Edit", {"file_path": R + "/SCRIP/src/runtime/rtx/rtx_match.s"}, none, 2, ["/rtx-asm-leaves"]),
        ("Edit of a corpus ref wants gates-and-witnesses and the language", "Edit", {"file_path": R + "/corpus/tests/pascal/ALL.ref"}, none, 2, ["/gates-and-witnesses", "/pascal"]),
        ("no transcript at all: the edit passes with a note", "Edit", {"file_path": R + "/SCRIP/src/lower/lower_raku.c"}, os.path.join(d, "absent.jsonl"), 0, []),
        ("Bash cp onto a bootstrap parser wants snocone-parser-patterns", "Bash", {"command": "cp /tmp/x.sc " + R + "/SCRIP/bootstrap/parser_raku.sc"}, none, 2, ["/snocone-parser-patterns"]),
        ("Edit of the collector wants gc-collector beside scrip-memory-model", "Edit", {"file_path": R + "/SCRIP/src/runtime/rt/gc_heap.c"}, none, 2, ["/gc-collector", "/scrip-memory-model"]),
        ("Edit of the call protocol wants runtime-calls", "Edit", {"file_path": R + "/SCRIP/src/runtime/rt/rt.c"}, none, 2, ["/runtime-calls"]),
        ("Edit of the Makefile wants scrip-build", "Edit", {"file_path": R + "/SCRIP/Makefile"}, none, 2, ["/scrip-build"]),
    ]
    bad = 0
    for i, (name, tool, inp, tr, want, words) in enumerate(cases, 1):
        rc, msg = judge(tool, inp, tr)
        ok = rc == want and all(w in msg for w in words) and (rc != 2 or "SKILL GATE" in msg)
        if rc == 0 and want == 0 and words == [] and tool == "Edit" and "lower_prolog" in str(inp) and "/scrip-c-code" in msg:
            ok = False
        print("  %s ARM %d: %s%s" % ("ok  " if ok else "RED ", i, name, "" if ok else " -- rc %d: %s" % (rc, msg[:160])))
        bad += 0 if ok else 1
    return 1 if bad else 0


def main(argv):
    if "--self-test" in argv:
        return self_test()
    if "--judge" in argv:   # --judge TOOL PATH TRANSCRIPT: a hand probe
        i = argv.index("--judge"); rc, msg = judge(argv[i + 1], {"file_path": argv[i + 2], "command": argv[i + 2]}, argv[i + 3] if len(argv) > i + 3 else "")
        print(rc, msg); return rc
    try:
        j = json.load(sys.stdin)
    except Exception:
        return 0
    rc, msg = judge(j.get("tool_name", ""), j.get("tool_input", {}) or {}, j.get("transcript_path", ""))
    if msg:
        sys.stderr.write(msg + "\n")
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
