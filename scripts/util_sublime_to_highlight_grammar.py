#!/usr/bin/env python3
"""util_sublime_to_highlight_grammar.py -- ONE CONVERTER TURNS A SUBLIME SYNTAX FILE INTO THE DATA A GENERIC HIGHLIGHTER READS
(Lon 2026-11-10: "If JupyterLab has HIGHLIGHTERS then we'll want to create ones for our languages." / "I sure hope that Jupyter Lab/Notebook has
REGEX-based syntax coloring then you could take the Sublime syntax files as a source."; the cio's design CIO-81; written by the cto 2026-11-11, CTO-597).

  util_sublime_to_highlight_grammar.py convert SYNTAX.sublime-syntax --out FILE.json    one syntax to one grammar
  util_sublime_to_highlight_grammar.py --write DIR    regenerate the four grammars of DIR from DIR/../../sublime
  util_sublime_to_highlight_grammar.py --check DIR    convert the four and compare with the JSON in DIR; rc 1 when one is stale or absent
  util_sublime_to_highlight_grammar.py --probe        the tool's own proof on two planted syntaxes

THE CLOSED SET it reads (anything else is a refusal naming the file, the context and the key; nothing is guessed): the top keys name, file_extensions,
first_line_match, scope, variables, contexts; in a context the keys match, scope, captures, push, set, pop (true or a count), include, meta_scope,
meta_content_scope, meta_include_prototype; a push or a set of a context's name, of a list of names, or of an inline list of rules; the prototype
context; in a pattern look-ahead, look-behind, the extended-mode marker (?x) at its start, the extended-mode group (?x: ... ), and the class \\h.
REFUSED in a pattern: an atomic group, a possessive quantifier, \\G \\A \\Z \\z \\K, a POSIX bracket, a Unicode property, a named group, an inline flag
other than a leading (?x), a conditional, a back-reference; and a pattern Python's re does not compile.

THE OUTPUT is JSON: name, file_extensions, scope, contexts; contexts maps a context's name to {meta_scope, meta_content_scope, rules}; a rule is
{match, scope, captures (group number to scope), and at most one of push (a list of names), set (a list of names), pop (a count)}. Every variable is
expanded, every include is resolved in place, and the prototype's rules stand first in every context that does not set meta_include_prototype false.
An inline context is named after the context that holds it, a number sign and its ordinal.

rc 0 done or current; rc 1 a grammar is stale or absent (--check), the probe disagrees; rc 2 a refusal or a file that cannot be read."""
import json, os, re, sys

LANGS = [("SNOBOL4", "snobol4"), ("Snocone", "snocone"), ("Icon", "icon"), ("Prolog", "prolog")]
TOP = {"name", "file_extensions", "first_line_match", "scope", "variables", "contexts", "version", "hidden"}
RULE = {"match", "scope", "captures", "push", "set", "pop", "include", "meta_scope", "meta_content_scope", "meta_include_prototype", "comment"}


class Refuse(Exception):
    pass


def atoms(pat):
    """The pattern as a list of (kind, text): 'esc' a backslash pair, 'class' a whole bracket class, 'ch' any other character."""
    out, i, n = [], 0, len(pat)
    while i < n:
        c = pat[i]
        if c == "\\" and i + 1 < n:
            out.append(("esc", pat[i:i + 2])); i += 2
        elif c == "[":
            j = i + 1
            if j < n and pat[j] == "^": j += 1
            if j < n and pat[j] == "]": j += 1
            while j < n and pat[j] != "]":
                j += 2 if pat[j] == "\\" and j + 1 < n else 1
            out.append(("class", pat[i:j + 1])); i = j + 1
        else:
            out.append(("ch", c)); i += 1
    return out


def regex(pat, where):
    """One Sublime pattern as a pattern Python's re and a JavaScript RegExp both read; a construct outside the closed set refuses."""
    lead = pat.startswith("(?x)")
    if lead: pat = pat[4:]
    out, at, i, groups = [], atoms(pat), 0, []
    while i < len(at):
        kind, t = at[i]
        nxt = "".join(x[1] for x in at[i + 1:i + 4])
        ext = groups[-1] if groups else lead
        if kind == "esc":
            if t == "\\h": t = "[0-9A-Fa-f]"
            elif t[1] in "GAZzK": raise Refuse("%s: the pattern uses %s" % (where, t))
            elif t[1] in "pP" and nxt.startswith("{"): raise Refuse("%s: the pattern uses a Unicode property" % where)
            elif t[1] in "123456789": raise Refuse("%s: the pattern uses a back-reference" % where)
            out.append(t)
        elif kind == "class":
            if "[:" in t: raise Refuse("%s: the pattern uses a POSIX bracket" % where)
            out.append(t.replace("\\h", "0-9A-Fa-f"))
        elif ext and t in " \t\r\n":
            pass
        elif ext and t == "#":
            while i + 1 < len(at) and at[i + 1][1] != "\n": i += 1
        elif t == "(" and nxt.startswith("?x:"):
            groups.append(True); out.append("(?:"); i += 3
        else:
            if t == "(":
                groups.append(ext)
                if nxt.startswith("?>"): raise Refuse("%s: the pattern uses an atomic group" % where)
                if nxt.startswith("?("): raise Refuse("%s: the pattern uses a conditional" % where)
                if nxt.startswith("?<") and nxt[2:3] not in ("=", "!"): raise Refuse("%s: the pattern uses a named group" % where)
                if nxt.startswith("?") and nxt[1:2] not in (":", "=", "!", "<"): raise Refuse("%s: the pattern uses an inline flag" % where)
            if t == ")" and groups: groups.pop()
            if t == "+" and out and out[-1] in ("*", "+", "?", "}") and not (len(out) > 1 and out[-2:] == ["?", "?"]):
                raise Refuse("%s: the pattern uses a possessive quantifier" % where)
            out.append(t)
        i += 1
    res = "".join(out)
    try:
        re.compile(res)
    except re.error as e:
        raise Refuse("%s: Python's re does not compile the pattern (%s): %s" % (where, e, res))
    return res


def convert(path):
    try:
        import yaml
    except ImportError:
        raise Refuse("PyYAML is not importable")
    try:
        d = yaml.safe_load(open(path, encoding="utf-8"))
    except Exception as e:
        raise Refuse("%s: cannot be read as YAML (%s)" % (path, e))
    base = os.path.basename(path)
    for k in d:
        if k not in TOP: raise Refuse("%s: the top key %s is outside the closed set" % (base, k))
    var = {k: str(v) for k, v in (d.get("variables") or {}).items()}

    def expand(s, where):
        for _ in range(64):
            t = re.sub(r"\{\{([A-Za-z_][A-Za-z0-9_]*)\}\}", lambda m: var[m.group(1)] if m.group(1) in var else (_ for _ in ()).throw(Refuse("%s: no variable %s" % (where, m.group(1)))), s)
            if t == s: return s
            s = t
        raise Refuse("%s: the variables do not reach a fixed point" % where)

    src = d.get("contexts") or {}
    if "main" not in src: raise Refuse("%s: no context main" % base)
    out, inline, named, bare = {}, {}, {}, set()

    def reach(c):
        """The prototype and every context it includes take no prototype, as in Sublime: else the prototype would include itself."""
        if c in bare or c not in src: return
        bare.add(c)
        for r in src[c] or []:
            if isinstance(r, dict) and "include" in r: reach(r["include"])

    reach("prototype")

    def names(v, ctx, key):
        """A push or a set target as a list of context names; an inline list of rules is registered under a generated name."""
        if isinstance(v, str): return [v]
        if isinstance(v, list) and v and all(isinstance(x, dict) for x in v):
            if id(v) not in named:
                named[id(v)] = "%s#%d" % (ctx.split("#")[0], len(inline) + 1)
                inline[named[id(v)]] = v
            return [named[id(v)]]
        if isinstance(v, list) and v and all(isinstance(x, (str, list)) for x in v):
            return [y for x in v for y in names(x, ctx, key)]
        raise Refuse("%s: context %s: a %s of %r is outside the closed set" % (base, ctx, key, type(v).__name__))

    def build(ctx, rules, proto, seen):
        meta = {"meta_scope": None, "meta_content_scope": None, "rules": []}
        own = True

        def add(rs, inc, chain):
            nonlocal own
            for n, r in enumerate(rs):
                if not isinstance(r, dict): raise Refuse("%s: context %s: rule %d is not a mapping" % (base, ctx, n + 1))
                for k in r:
                    if k not in RULE: raise Refuse("%s: context %s: the key %s is outside the closed set" % (base, ctx, k))
                if "include" in r:
                    tgt = r["include"]
                    if tgt not in src: raise Refuse("%s: context %s: include of the unknown context %s" % (base, ctx, tgt))
                    if tgt in chain: raise Refuse("%s: context %s: include of %s is a cycle" % (base, ctx, tgt))
                    add(src[tgt], True, chain + [tgt])
                    continue
                if "match" not in r:
                    if not inc:
                        if "meta_scope" in r: meta["meta_scope"] = r["meta_scope"]
                        if "meta_content_scope" in r: meta["meta_content_scope"] = r["meta_content_scope"]
                        if r.get("meta_include_prototype") is False: own = False
                    continue
                where = "%s: context %s: rule %d" % (base, ctx, n + 1)
                o = {"match": regex(expand(str(r["match"]), where), where)}
                if "scope" in r: o["scope"] = r["scope"]
                if "captures" in r: o["captures"] = {str(int(g)): s for g, s in r["captures"].items()}
                acts = [k for k in ("push", "set", "pop") if k in r]
                if len(acts) > 1: raise Refuse("%s: more than one of push, set and pop" % where)
                if acts and acts[0] == "pop":
                    if r["pop"] is True: o["pop"] = 1
                    elif isinstance(r["pop"], int) and r["pop"] > 0: o["pop"] = r["pop"]
                    else: raise Refuse("%s: pop of %r" % (where, r["pop"]))
                elif acts:
                    o[acts[0]] = names(r[acts[0]], ctx, acts[0])
                meta["rules"].append(o)

        add(rules, False, [ctx])
        if proto and own and ctx not in bare:
            keep, meta["rules"] = meta["rules"], []
            add(src["prototype"], True, [ctx, "prototype"])
            meta["rules"] = meta["rules"] + keep
        return meta

    proto = "prototype" in src
    for c, rules in src.items():
        out[c] = build(c, rules or [], proto, set())
    done = set()
    while set(inline) - done:
        for c in sorted(set(inline) - done):
            done.add(c)
            out[c] = build(c, inline[c], proto, set())
    for c, m in out.items():
        for r in m["rules"]:
            for k in ("push", "set"):
                for t in r.get(k, []):
                    if t not in out: raise Refuse("%s: context %s: %s of the unknown context %s" % (base, c, k, t))
    return {"name": d.get("name"), "file_extensions": d.get("file_extensions") or [], "scope": d.get("scope"), "contexts": out}


def text(g):
    return json.dumps(g, indent=1, sort_keys=True, ensure_ascii=False) + "\n"


def sources(d):
    return os.path.normpath(os.path.join(d, "..", "..", "sublime"))


def probe():
    import tempfile
    t = tempfile.mkdtemp(prefix="sublime-grammar-probe-")
    good = os.path.join(t, "Probe.sublime-syntax")
    open(good, "w").write("%YAML 1.2\n---\nname: Probe\nfile_extensions: [prb]\nscope: source.probe\nvariables:\n  id: '[A-Za-z_]{{tail}}*'\n  tail: '[A-Za-z0-9_]'\n"
                          "contexts:\n  prototype:\n    - include: notes\n  notes:\n    - match: '#.*$'\n      scope: comment.line\n  main:\n    - match: '(?x) \\b ( if | then ) \\b  # the two words'\n      scope: keyword.control\n"
                          "    - match: '\"'\n      scope: punctuation.definition.string.begin\n      push:\n        - meta_scope: string.quoted.double\n        - meta_include_prototype: false\n"
                          "        - match: '\"'\n          pop: true\n    - include: names\n  names:\n    - match: '{{id}}'\n      scope: variable.other\n    - match: '0x\\h+'\n      scope: constant.numeric\n")
    want = {"name": "Probe", "file_extensions": ["prb"], "scope": "source.probe", "contexts": {
        "prototype": {"meta_scope": None, "meta_content_scope": None, "rules": [{"match": "#.*$", "scope": "comment.line"}]},
        "main": {"meta_scope": None, "meta_content_scope": None, "rules": [{"match": "#.*$", "scope": "comment.line"}, {"match": "\\b(if|then)\\b", "scope": "keyword.control"},
                 {"match": "\"", "scope": "punctuation.definition.string.begin", "push": ["main#1"]}, {"match": "[A-Za-z_][A-Za-z0-9_]*", "scope": "variable.other"},
                 {"match": "0x[0-9A-Fa-f]+", "scope": "constant.numeric"}]},
        "names": {"meta_scope": None, "meta_content_scope": None, "rules": [{"match": "#.*$", "scope": "comment.line"}, {"match": "[A-Za-z_][A-Za-z0-9_]*", "scope": "variable.other"},
                  {"match": "0x[0-9A-Fa-f]+", "scope": "constant.numeric"}]},
        "notes": {"meta_scope": None, "meta_content_scope": None, "rules": [{"match": "#.*$", "scope": "comment.line"}]},
        "main#1": {"meta_scope": "string.quoted.double", "meta_content_scope": None, "rules": [{"match": "\"", "pop": 1}]}}}
    bad = os.path.join(t, "Bad.sublime-syntax")
    open(bad, "w").write("%YAML 1.2\n---\nname: Bad\nscope: source.bad\ncontexts:\n  main:\n    - match: '(?>a+)b'\n      scope: keyword\n")
    why = []
    try:
        got = convert(good)
        if got != want: why.append("the planted syntax converts to %s" % json.dumps(got, sort_keys=True))
    except Refuse as e:
        why.append("the planted syntax was refused: %s" % e)
    try:
        convert(bad); why.append("the atomic group was not refused")
    except Refuse as e:
        if "atomic group" not in str(e): why.append("the atomic group was refused for another reason: %s" % e)
    if regex("a(?x: b | c  # two\n )d e", "probe") != "a(?:b|c)d e": why.append("the extended-mode group reads %r" % regex("a(?x: b | c  # two\n )d e", "probe"))
    for p, word in (("a++", "possessive"), ("\\Gx", "\\G"), ("(?i)x", "inline flag"), ("(a)\\1", "back-reference"), ("[[:alpha:]]", "POSIX")):
        try:
            regex(p, "probe"); why.append("%s was not refused" % p)
        except Refuse as e:
            if word not in str(e): why.append("%s was refused for another reason: %s" % (p, e))
    if regex("\\++x?", "probe") != "\\++x?" or regex("[+]+", "probe") != "[+]+" or regex("a+?", "probe") != "a+?": why.append("a plain quantifier after a plus was changed or refused")
    print("SUBLIME_GRAMMAR_PROBE ok" if not why else "SUBLIME_GRAMMAR_PROBE RED: " + "; ".join(why))
    return 0 if not why else 1


def main(a):
    try:
        if a[:1] == ["--probe"]: return probe()
        if a[:1] == ["convert"] and len(a) == 4 and a[2] == "--out":
            open(a[3], "w", encoding="utf-8").write(text(convert(a[1]))); return 0
        if a[:1] in (["--write"], ["--check"]) and len(a) == 2:
            stale = 0
            for src, name in LANGS:
                want = text(convert(os.path.join(sources(a[1]), src + ".sublime-syntax"))); p = os.path.join(a[1], name + ".json")
                if a[0] == "--write":
                    os.makedirs(a[1], exist_ok=True); open(p, "w", encoding="utf-8").write(want)
                    print("SUBLIME_GRAMMAR wrote %s contexts=%d rules=%d" % (p, len(json.loads(want)["contexts"]), sum(len(c["rules"]) for c in json.loads(want)["contexts"].values())))
                elif not os.path.exists(p) or open(p, encoding="utf-8").read() != want:
                    stale += 1; print("SUBLIME_GRAMMAR STALE %s (regenerate with --write %s)" % (p, a[1]))
            if a[0] == "--check": print("SUBLIME_GRAMMAR_CHECK grammars=%d stale=%d" % (len(LANGS), stale))
            return 1 if stale else 0
    except Refuse as e:
        print("REFUSE(2) [util_sublime_to_highlight_grammar]: %s" % e); return 2
    print(__doc__); return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
