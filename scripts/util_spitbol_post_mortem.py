#!/usr/bin/env python3
"""util_spitbol_post_mortem.py <oracle-stdout> <body-out> -- remove SPITBOL's fatal-error post-mortem block from sbl's stdout.

ceo CEO-1316 (2026-09-27), on Lon's word "I want to see TPgm go to 8/8": a program whose sbl answer is a fatal post-mortem at rc 0
is GRADED, not marked OUTSIDE. The block is removed ONLY when it has exactly the measured shape, and any other shape REFUSES rc 2.
The caller compares the remainder byte for byte with SCRIP's stdout and grades the banner's code and statement against SCRIP's
stderr through util_render_error_voice.py spitbol. The accounting is never graded (CEO-420 (b): memory used/left, REGENERATIONS,
stmts executed and execution time belong to the engine, not the program -- the rewind-174 gate's precedent).

THE SHAPE, measured on test4..test8 of spitbol_testpgms (sbl -bf, stdout only) and derived line by line from stopr in
/home/resources/x64/sbl.min (~16720-16800):
    3 blank lines
    <file>(<line>) : ERROR <nnn> -- <text>
    5 blank lines
    in file              <file>            <- must equal the banner's file
    in line              <line>            <- must equal the banner's line
    in statement         <n>               <- the graded statement
    stmts executed       <n>
    execution time msec  <ms>
    stmt / microsec      <n>   \
    stmt / millisec      <n>    >  printed by stopr exactly when <ms> > 0 (ile stpr2 skips them at 0): all three, or none
    stmt / second        <n>   /
    REGENERATIONS        <n>
    memory used (bytes)  <n>
    memory left (bytes)  <n>
    1 blank line                               (stopr's "one more blank for luck"; a DUMP, when requested, follows it)
The other shapes stopr can print -- no "in line" for an error inside a collection, no statement count or time under a negative
&STLIMIT -- were never measured here, so they refuse rather than guess.

EXIT: 0 the block was found and removed; stdout carries "BANNER<TAB><banner line>" and "STATEMENT<TAB><n>", <body-out> the rest,
byte for byte. 3 no post-mortem banner in the stream (the caller grades normally). 2 REFUSED: a banner is present but the block is
not the measured shape, or more than one banner, or an unreadable file.
"""
import re, sys

BANNER = re.compile(r"^(\S.*)\((\d+)\) : ERROR (\d{3}) -- (.+)$")
def refuse(msg):
    sys.stderr.write("REFUSE(rc=2): util_spitbol_post_mortem.py: %s\n" % msg); sys.exit(2)
if len(sys.argv) != 3:
    refuse("needs <oracle-stdout> <body-out>; got %d argument(s)" % (len(sys.argv) - 1))
try:
    raw = open(sys.argv[1], "rb").read().decode("utf-8", "surrogateescape")
except OSError as e:
    refuse("cannot read %s: %s" % (sys.argv[1], e))
lines = raw.splitlines(keepends=True)
text = [l.rstrip("\n") for l in lines]
hits = [i for i, t in enumerate(text) if BANNER.match(t)]
if not hits:
    sys.exit(3)
if len(hits) > 1:
    refuse("%d post-mortem banners at lines %s -- one fatal error ends a SPITBOL run, so this is not the measured shape" % (len(hits), [h + 1 for h in hits]))
b = hits[0]
m = BANNER.match(text[b]); bfile, bline = m.group(1), m.group(2)
def need(cond, what):
    if not cond:
        refuse("line %d: %s -- not the measured post-mortem shape (banner at line %d: %r)" % (min(k, len(text)) + 1, what, b + 1, text[b]))
k = b - 3
need(k >= 0 and all(text[j] == "" for j in range(k, b)), "three blank lines before the banner")
k = b + 1
need(b + 5 < len(text) and all(text[j] == "" for j in range(b + 1, b + 6)), "five blank lines after the banner")
k = b + 6
def field(label, pat):
    global k
    mm = re.match(r"^" + re.escape(label) + r" +(" + pat + r")$", text[k]) if k < len(text) else None
    need(mm is not None, "expected %r" % label)
    k += 1
    return mm.group(1)
need(field("in file", r"\S.*") == bfile, "'in file' does not name the banner's file")
need(field("in line", r"\d+") == bline, "'in line' does not name the banner's line")
stno = field("in statement", r"\d+")
field("stmts executed", r"\d+")
ms = int(field("execution time msec", r"\d+"))
if ms > 0:
    for lab in ("stmt / microsec", "stmt / millisec", "stmt / second"):
        field(lab, r"\d+")
else:
    need(k < len(text) and not text[k].startswith("stmt / "), "throughput lines printed although execution time msec is 0")
field("REGENERATIONS", r"\d+")
field("memory used (bytes)", r"\d+")
field("memory left (bytes)", r"\d+")
need(k < len(text) and text[k] == "", "the one blank line after the accounting")
end = k
with open(sys.argv[2], "wb") as fh:
    fh.write("".join(lines[:b - 3] + lines[end + 1:]).encode("utf-8", "surrogateescape"))
sys.stdout.write("BANNER\t%s\nSTATEMENT\t%s\n" % (text[b], stno))
