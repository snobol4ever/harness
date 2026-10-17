#!/usr/bin/env python3
"""
monitor_sync_bin.py — binary-protocol sync-step monitor controller.

Reads fixed-size binary records from each participant's ready FIFO,
compares them as (kind, name_string, type, value_bytes) tuples, and
writes 'G' (go) or 'S' (stop) to each participant's go FIFO.

Wire format (matches monitor_wire.h):
    13-byte header LE: u32 kind | u32 name_id | u8 type | u32 value_len
    value_len bytes of value (varies by type)

SN-26-bridge-coverage-e — streaming intern on the wire.

Names are NOT loaded from a sidecar file.  Participants emit MWK_NAME_DEF
records inline before any record using a fresh name_id.  The controller
maintains a per-participant intern table populated from those NAME_DEF
records.  NAME_DEFs are acked with 'G' like any other record but are
not surfaced as semantic events for divergence comparison — different
participants may assign the same name different ids without diverging,
since comparison is on the resolved name string, not the id.

CLI shape (single, simple):

    monitor_sync_bin.py NAME:READY_FIFO:GO_FIFO ...

The first PARTICIPANT is the consensus oracle.  Divergences are reported
relative to it.

Exit codes:
    0   all participants reached END and no GRADED event diverged -- read the
        VERDICT line beside it: AGREE=a DIVERGE=0 UNGRADED=u, and u > 0 means
        u steps were never compared (an untyped value on one side), each named
    1   divergence — first disagreement reported, all participants stopped
    2   timeout / bad CLI
    3   protocol error (bad header, short read, etc.)

⛔ THE VERDICT LINE (row monitor-the-controller-reads-an-untyped-value-as-agree-…,
the coo on the ceo's dispatch, 2026-09-23): every lock-step the controller
compares is graded AGREE, DIVERGE or UNGRADED, and every exit path prints
    [ctrl] VERDICT AGREE=a DIVERGE=d UNGRADED=u of n compared step(s) ...
with a + d + u == n.  An UNGRADED step is one where kind and name agree but a
participant sent MWT_UNKNOWN, so its value was never compared; it is NEVER a
match and never folded into AGREE (see grade_keys).
"""

import errno
import fcntl
import os
import struct
import sys
import time
from collections import namedtuple, deque

# How many last-agreed records to keep in the circular buffer and print on
# DIVERGE — gives the "last-agree + first-disagree" context RULES.md
# "Sync-step monitor — read the divergence point, not the trace" calls for.
# Overridable via MONITOR_LAST_AGREE_TRAIL env var (integer >= 1).
# The circular buffer is a collections.deque(maxlen=N) — O(1) append/evict.
_default_history = 5
try:
    DIVERGE_HISTORY = max(1, int(os.environ.get('MONITOR_LAST_AGREE_TRAIL', '') or _default_history))
except ValueError:
    DIVERGE_HISTORY = _default_history

HDR_FMT  = '<IIBI'   # u32 kind, u32 name_id, u8 type, u32 value_len
HDR_SIZE = struct.calcsize(HDR_FMT)
assert HDR_SIZE == 13, "header must be 13 bytes"

# Event kinds — keep aligned with monitor_wire.h MWK_*
MWK_VALUE     = 1
MWK_CALL      = 2
MWK_RETURN    = 3
MWK_END       = 4
MWK_LABEL     = 5
MWK_NAME_DEF  = 6
# S-2-bridge-7-byrd-pattern: per-AST-node Byrd-box pattern-match events.
MWK_PM_CALL   = 7
MWK_PM_EXIT   = 8
MWK_PM_REDO   = 9
MWK_PM_FAIL   = 10
# ⛔⭐ THE OUTPUT EVENT (coo 2026-09-25, row instruments-the-monitor-grades-no-output-event-so-a-wrong-value-written-without-an-
# assignment-reads-agree; ceo CEO-1272 on hq_icon's measurement): a wrong value written straight to standard output -- write(f(x)),
# OUTPUT = f(X), writeln(g) -- was never an event, so both sides agreed event for event over a wrong answer. A participant now sends
# the bytes it writes to standard output as MWK_OUTPUT records (name_id NONE, type STRING), and announces once, before its first
# statement, that it speaks OUTPUT: an MWK_OUTPUT record with name_id OUTPUT_HELLO and no bytes. OUTPUT records are NOT paired step for
# step -- two engines need not split a write() into the same pieces -- so the controller absorbs them into one byte stream per
# participant and, at every compared step and at the end, requires the streams to agree up to the shorter one; the first differing
# byte is a DIVERGE, and a stream left longer at END is one. Only when EVERY participant has said hello is output graded: the two sides
# land in order (the oracle fork first, then the SCRIP plug), and until both speak OUTPUT the VERDICT line says OUTPUT=UNGRADED(names).
MWK_OUTPUT    = 11
OUTPUT_HELLO  = 0xfffffffe

KIND_NAMES = {
    1: 'VALUE', 2: 'CALL', 3: 'RETURN', 4: 'END',
    5: 'LABEL', 6: 'NAME_DEF',
    7: 'PM_CALL', 8: 'PM_EXIT', 9: 'PM_REDO', 10: 'PM_FAIL',
}

# Type tags (must match monitor_wire.h MWT_*)
TYPE_NAMES = {
    0: 'NULL',  1: 'STRING', 2: 'INTEGER', 3: 'REAL',  4: 'NAME',
    5: 'PATTERN', 6: 'EXPRESSION', 7: 'ARRAY', 8: 'TABLE',
    9: 'CODE', 10: 'DATA', 11: 'FILE', 255: 'UNKNOWN',
}

NAME_ID_NONE = 0xffffffff

EVENT_TIMEOUT_S = 60.0    # generous; beauty self-host is slow

# Raw record off the wire — name_id is dialect-local until resolved.
Event = namedtuple('Event', 'kind name_id type value')


def name_for_id(names_table, name_id):
    """Resolve a name_id against a participant's intern table.

    names_table is a dict {id -> bytes}. NAME_ID_NONE -> '' (used for END/LABEL).
    Unknown ids surface as '(id=N)' so downstream comparison still has a stable
    string — should not happen with well-formed wire output.
    """
    if name_id == NAME_ID_NONE:
        return ''
    nm = names_table.get(name_id)
    if nm is None:
        return f'(id={name_id})'
    try:
        return nm.decode('utf-8', errors='backslashreplace')
    except Exception:
        return repr(nm)


# ---------------------------------------------------------------------------
# read_record — read one full record (header + value bytes) from fd.
# ---------------------------------------------------------------------------

def read_exact(fd, n, timeout_s):
    """Read exactly n bytes from fd or return None on EOF."""
    deadline = time.monotonic() + timeout_s
    buf = b''
    while len(buf) < n:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return None
        try:
            chunk = os.read(fd, n - len(buf))
        except BlockingIOError:
            time.sleep(0.001)
            continue
        if not chunk:
            return None  # EOF
        buf += chunk
    return buf


def read_record(fd, timeout_s):
    hdr = read_exact(fd, HDR_SIZE, timeout_s)
    if hdr is None or len(hdr) != HDR_SIZE:
        return None
    kind, name_id, type_tag, value_len = struct.unpack(HDR_FMT, hdr)
    # A participant that dies mid-write (e.g. a SIGSEGV between header and
    # payload, or a torn write racing process death) can leave garbage on the
    # pipe that decodes as a huge value_len (the field is a raw u32, so up to
    # ~4GB).  Attempting os.read()/buf accumulation at that scale crashes the
    # CONTROLLER with an uncaught MemoryError, destroying the one piece of
    # forensic information this instrument exists to preserve: which
    # participant died and after which last-good event.  Cap it and raise the
    # same ValueError the short-read path already uses, so the existing
    # per-step try/except in run() reports it as a named PROTOCOL ERR instead
    # (2026-08-12, BOARD s43, found while chasing the calculator-1 SIGSEGV).
    MAX_SANE_VALUE_LEN = 16 * 1024 * 1024  # 16MB; no legitimate wire value is near this
    if value_len > MAX_SANE_VALUE_LEN:
        raise ValueError(f'insane value_len {value_len} (>{MAX_SANE_VALUE_LEN}) — '
                          f'torn/garbage header, likely a mid-write participant crash')
    if value_len > 0:
        val = read_exact(fd, value_len, timeout_s)
        if val is None or len(val) != value_len:
            raise ValueError(f'short value read: wanted {value_len} got {len(val) if val else 0}')
    else:
        val = b''
    return Event(kind, name_id, type_tag, val)


def read_semantic_record(f, timeout_s):
    """Read records from participant f until a non-NAME_DEF record is seen.

    ONLY NAME_DEF records are absorbed here — they are wire-protocol
    bookkeeping (binding name_id -> name bytes) and carry no semantics
    of their own.  Every other record kind (VALUE, CALL, RETURN, END,
    LABEL) is returned to the caller for sync-step comparison.

    LABEL records are EXPLICITLY comparison-eligible: a LABEL divergence
    means the runtimes entered different statements (different STNO),
    which is a structural-flow bug that must surface immediately.  Do
    not extend this absorption loop to LABEL or any future "informational"
    kind without an explicit goal-level decision — silently filtering
    LABEL would hide exactly the class of bug the monitor exists to
    catch (control-flow disagreement before any value disagreement).

    NAME_DEF records are acked with 'G' here so the participant can
    continue; the participant still cannot run ahead of the controller
    because each ack is one-record-at-a-time.

    Returns Event or None on EOF.  Raises ValueError on protocol error.
    """
    while True:
        ev = read_record(f['rd'], timeout_s)
        if ev is None:
            return None
        if ev.kind in (MWK_CALL, MWK_RETURN) and SKIP_CALL_RETURN:
            try:
                os.write(f['gw'], b'G')
            except OSError:
                return None
            continue
        if ev.kind == MWK_VALUE and SKIP_VALUE_NAMES and (lambda _n: (_n.decode('utf-8','replace') if isinstance(_n, (bytes, bytearray)) else _n) in SKIP_VALUE_NAMES)(f['names'].get(ev.name_id, '')):
            try:
                os.write(f['gw'], b'G')
            except OSError:
                return None
            continue
        if ev.kind == MWK_OUTPUT:
            if ev.name_id == OUTPUT_HELLO:
                f['out_capable'] = True
            else:
                f['out'] += ev.value
            if f['log_fp'] and ev.name_id != OUTPUT_HELLO:
                f['log_fp'].write(f'  OUTPUT {bytes(ev.value)!r}\n')
            try:
                os.write(f['gw'], b'G')
            except OSError:
                return None
            continue
        if ev.kind != MWK_NAME_DEF:
            return ev
        # Streaming intern: register binding, ack, loop for next record.
        f['names'][ev.name_id] = ev.value
        try:
            os.write(f['gw'], b'G')
        except OSError:
            return None  # participant closed early


# ---------------------------------------------------------------------------
# Resolve an Event to a comparable tuple using a per-participant names dict.
#
# All non-NAME_DEF kinds participate in this comparison — including LABEL.
# A LABEL divergence (same step, different STNO) means the runtimes are
# executing different statements; that is a real structural-flow bug,
# usually a control-flow disagreement upstream.  Do not be tempted to
# filter LABELs out of the comparison to "reach" a value divergence —
# the LABEL divergence IS the divergence.
# ---------------------------------------------------------------------------

def event_key(ev, names_table):
    """Return (kind, name_string, type, value_bytes) — the comparable tuple."""
    if ev is None:
        return None
    return (ev.kind, name_for_id(names_table, ev.name_id), ev.type, ev.value)


# MWT_UNKNOWN sentinel — an untyped value: the step is UNGRADED, never AGREE.
# See grade_keys below.
MWT_UNKNOWN = 255

# The three grades of one compared pair (and of one lock-step).
AGREE    = 'AGREE'
DIVERGE  = 'DIVERGE'
UNGRADED = 'UNGRADED'

# <lval> sentinel — wildcard on name field.  See keys_match below.
LVAL_SENTINEL = '<lval>'

# Per-participant blanket-name wildcard — set via env var.
# MONITOR_NAME_WILDCARD="spl"  (comma-separated participant names) treats
# the named participants' name field as a wildcard for ALL events, not
# just <lval>.  Used to advance the wire past known bridge-side bugs
# where one runtime emits stale-memory junk in the name slot for
# aggregate-element stores (SPITBOL fake-vrblk in spl_vrblk_name —
# see GOAL-NET-BEAUTY-SELF S-2-bridge-7 notes).  This lets bug-finding
# proceed on the trustworthy side (e.g. dot) without first having to
# patch the broken side's bridge.  Real value-byte / kind divergences
# are still reported.  Default: empty (no wildcard).
WILDCARD_NAMES_PARTICIPANTS = set(
    p.strip() for p in os.environ.get('MONITOR_NAME_WILDCARD', '').split(',')
    if p.strip()
)

# MONITOR_SKIP_EXTRA_KEYWORD_VALUES=1 — opt-in workaround for the spl bridge's
# missing VALUE emission on keyword assignments (& assignments such as
# &FULLSCAN = 1).  When dot or csn emits a VALUE for a keyword, spl emits
# nothing and advances directly to the next LABEL.  This produces a divergence
# where one participant has VALUE-on-keyword and the other has LABEL/anything-else.
#
# When this flag is set and a divergence matches that pattern, the controller
# acks only the VALUE-emitting side(s) with 'G', reads their next record, and
# retries comparison.  Bounded by SKIP_MAX_PER_STEP to prevent unbounded read-
# ahead.  Off by default — setting it is an explicit acknowledgment that one
# side's bridge is incomplete.
#
# Long-term fix: SN-26-bridge-coverage extends the spl bridge to emit VALUE
# for keyword stores (probably hooks zystt or the same fire-point as &x=v
# scalar stores).  When that lands, this skip becomes a no-op.
SKIP_EXTRA_KEYWORD_VALUES = os.environ.get('MONITOR_SKIP_EXTRA_KEYWORD_VALUES', '').strip() in ('1', 'true', 'yes', 'on')
SKIP_MAX_PER_STEP = 4  # at most this many extra reads per side per comparison step

# MONITOR_SKIP_BARE_LABEL_STNO=1 — opt-in workaround for a monitor-only false
# DIVERGE on bare label-only statement lines (e.g. a line consisting solely of
# "EMIT_x", the common DEFINE(...) :(X_x) ... X_x skip-target idiom used
# throughout the SNOBOL4 corpus).  SPITBOL's oracle bridge counts and traces a
# bare label line as its own null statement (LABEL event at its own stno --
# manual Ch.4 p.28: "You can have a program line consisting of just a label");
# scrip's bridge does not emit a distinct LABEL event for it, landing directly
# on the next real statement's stno instead.  Verified BENIGN via a minimal
# 2-DEFINE reproducer (BOARD, 2026-08-12 s43): both engines print identical,
# correct output despite the trace disagreement -- this is a monitor
# instrumentation gap, not a control-flow bug.
#
# When set, and a LABEL/LABEL disagreement is seen where one or more
# participants' current stno resolves (via the static stno_map) to a source
# line that is a bare label token with no statement body, those participants
# only are advanced one record and comparison is retried.  Bounded by
# SKIP_MAX_PER_STEP.  A LABEL divergence NOT matching this specific,
# stno-verified pattern still surfaces immediately -- this is not a blanket
# LABEL filter (see the explicit prohibition on that in read_semantic_record's
# docstring above).
#
# Long-term fix: extend scrip's monitor bridge to emit LABEL for label-only
# statements, matching the oracle's statement-counting model exactly.
SKIP_BARE_LABEL_STNO = os.environ.get('MONITOR_SKIP_BARE_LABEL_STNO', '').strip() in ('1', 'true', 'yes', 'on')

# MONITOR_SKIP_CALL_RETURN=1 — opt-in bracketing aid (s196): drop CALL/RETURN events
# from BOTH streams before comparison.  Exists because scrip's SCC staged call road
# carries no CALL/RETURN taps yet (row scc-road-call-taps): a semantically-identical
# run diverges on the missing event shape at every staged call, which blocks VALUE/
# LABEL bracketing of the shipped road.  A dropped event is ACKed like NAME_DEF so
# the sync-step cadence is preserved.  Never on by default: with taps present the
# CALL/RETURN stream is load-bearing coverage.
SKIP_CALL_RETURN = os.environ.get('MONITOR_SKIP_CALL_RETURN', '').strip() in ('1', 'true', 'yes', 'on')

# MONITOR_SKIP_VALUE_NAMES=a,b,c — opt-in bracketing aid (s196): drop VALUE events for the
# named variables from BOTH streams (ack'd like NAME_DEF so cadence holds).  Exists to peel
# a known one-sided tap gap (e.g. scrip's NRETURN-name conditional commit not yet emitting
# VALUE) so the bracket can advance to the next semantic divergence.
SKIP_VALUE_NAMES = set(p.strip() for p in os.environ.get('MONITOR_SKIP_VALUE_NAMES', '').split(',') if p.strip())


def _is_bare_label_stno(stno_map, stno):
    """True iff stno_map[stno]'s source text is a single whitespace-free
    token (a label with no statement body) -- e.g. 'EMIT_x'.  Conservative:
    anything with internal whitespace (a real statement body, or a
    label+Goto-only line) does NOT match, so this only fires on the exact,
    verified-benign class."""
    if stno is None or stno not in stno_map:
        return False
    _fn, _ln, text = stno_map[stno]
    text = text.strip()
    return bool(text) and ' ' not in text and '\t' not in text


def _label_stno_of(ev):
    """Decode the integer stno carried by a LABEL event's INTEGER payload, or
    None if ev is not a LABEL / not decodable."""
    if ev is None or ev.kind != MWK_LABEL or ev.type != 2 or len(ev.value) != 8:
        return None
    return struct.unpack('<q', ev.value)[0]

# MONITOR_PM_NAME_WILDCARD=1 — wildcard the name field on PM_CALL/EXIT/REDO/FAIL
# events.  The dot side emits per-pattern-class tags (e.g. *snoString, BREAK,
# LITERAL, ConditionalVariableAssociationPattern), while the spl side emits a
# fixed "<spl-pm>" sentinel because SPITBOL's SIL pattern nodes are dispatched
# by code address with no string-tag table.  Real structural divergence still
# surfaces via the cursor field (low-32 bits of the value payload) and the
# event sequence; the per-side node-tag is decorative metadata only.
#
# Additionally, when this flag is set, PM event value-byte comparison is
# narrowed to the low 32 bits of the 8-byte payload (the cursor).  spl packs
# (cursor | node_addr << 32) into the high 32 bits for forensic visibility;
# dot packs only the cursor.  Comparing the full 8 bytes would diverge on
# every PM event because the node-addr portion differs by construction.
PM_NAME_WILDCARD = os.environ.get('MONITOR_PM_NAME_WILDCARD', '').strip() in ('1', 'true', 'yes', 'on')

PM_KINDS = (MWK_PM_CALL, MWK_PM_EXIT, MWK_PM_REDO, MWK_PM_FAIL)


def grade_keys(a, b, a_name_wild=False, b_name_wild=False):
    """Grade two event_key tuples: AGREE, DIVERGE or UNGRADED.

      1. MWT_UNKNOWN on the type field — the pair is UNGRADED.
         A participant's bridge may not yet have full type-block
         discrimination (e.g. SPITBOL's spl_block_to_wire returns
         MWT_UNKNOWN for nmblk/ptblk/atblk/tbblk/cdblk/efblk because
         the type-word externs are not exported in osint.h; rkx sends
         a Rat as MWT_UNKNOWN with no bytes).  Such a pair cannot
         DIVERGE on its type or value bytes -- the run must not stop on
         a bridge's missing coverage -- but nothing about its value was
         compared, so it is UNGRADED: counted and named on the VERDICT
         line, never a match.
         ⛔ THIS WAS A WILDCARD THAT READ AGREE until 2026-09-23 (row
         monitor-the-controller-reads-an-untyped-value-as-agree-…, the
         cfo's CFO-152 finding): a wrong SCRIP Rat against rkx's UNKNOWN
         read AGREE, and so did anything SCRIP sent against a SPITBOL
         TABLE/PATTERN/NAME -- a pass nobody measured.  Kind and name
         are still graded under UNKNOWN (a mismatch there is DIVERGE),
         and two real typed tags that disagree (STRING vs INTEGER)
         still DIVERGE.

      2. '<lval>' on the name field — strictly less informative.
         The pure-observer protocol contract says aggregate-element
         stores (a<i>=v, d<'k'>=v) are anonymous lvalues with no
         meaningful single name.  csn and the original dot emitted
         '<lval>'.  S-2-bridge-7-lval (snobol4dotnet 2414a26) enriched
         dot to emit the collection name (e.g. 'UTF') as a debugging
         aid — strictly more informative.  Until SN-26-bridge-coverage
         backports the same enrichment to csn (and addresses spl's
         fake-vrblk bug), the wire shows '<lval>' on csn / '<lval>' or
         junk on spl / collection-name on dot.  Treating '<lval>' as
         a wildcard lets the run advance through aggregate stores when
         one side has the enriched name and the other has the sentinel.
         Real name disagreement (e.g. dot's 'S' vs spl's 'T' on a
         scalar store) still flags DIVERGE.

      3. Per-participant blanket name wildcard — opt-in via env var.
         When MONITOR_NAME_WILDCARD lists a participant, that
         participant's name field is wildcarded for ALL events.
         Used to drive the wire forward past known bridge bugs in a
         specific runtime (e.g. SPITBOL's fake-vrblk in
         spl_vrblk_name producing stale-memory names like 'ss' on
         table-element stores).  See SN-26-bridge-coverage in
         GOAL-LANG-SNOBOL4 for the long-term fix.  This wildcard is
         OFF by default; setting it is an explicit acknowledgment
         that one side's name-emission is untrusted.

    The name wildcards apply ONLY when kind, value bytes, and the
    unmasked fields all match — they soften the comparison without ever
    masking a value-byte or kind divergence.  Those are the load-bearing
    fields of the protocol, and a pair whose value bytes were never
    compared (1.) is UNGRADED, not AGREE.
    """
    if a is None or b is None:
        return AGREE if a is b else DIVERGE
    (ak, an, at, av) = a
    (bk, bn, bt, bv) = b
    if ak != bk:
        return DIVERGE

    # S-2-bridge-7-byrd-pattern: PM events get cursor-only value comparison
    # and a name-field wildcard when MONITOR_PM_NAME_WILDCARD is set.
    # spl packs (cursor | node_addr << 32) in the 8-byte LE payload; dot
    # packs only the cursor.  Mask to low 32 bits before comparing.
    if PM_NAME_WILDCARD and ak in PM_KINDS:
        if at != bt:
            return DIVERGE
        a_cur = struct.unpack('<I', av[:4])[0] if len(av) >= 4 else 0
        b_cur = struct.unpack('<I', bv[:4])[0] if len(bv) >= 4 else 0
        return AGREE if a_cur == b_cur else DIVERGE
    # MWT_UNKNOWN on either side: type AND value bytes are not compared
    # (an UNKNOWN side sends no bytes, e.g. spl on a TABLE, rkx on a Rat),
    # so the pair cannot DIVERGE on them -- and cannot AGREE on them
    # either.  The name is still graded below.
    unknown_present = (at == MWT_UNKNOWN) or (bt == MWT_UNKNOWN)
    if not unknown_present and av != bv:
        return DIVERGE
    if not unknown_present and at != bt:
        return DIVERGE
    name_ok = (an == bn) or (an == LVAL_SENTINEL) or (bn == LVAL_SENTINEL) \
              or a_name_wild or b_name_wild
    if not name_ok:
        return DIVERGE
    return UNGRADED if unknown_present else AGREE


def keys_match(a, b, a_name_wild=False, b_name_wild=False):
    """True iff grade_keys() grades the pair AGREE.  An UNGRADED pair is
    NOT a match: use grade_keys() wherever UNGRADED must be told apart
    from DIVERGE (the controller's lock-step does)."""
    return grade_keys(a, b, a_name_wild, b_name_wild) == AGREE


UNGRADED_NAMES_SHOWN = 12


def ungraded_label(events):
    """The name an UNGRADED step is counted under: the first real name any
    participant resolved (an empty or '<lval>' name yields to a real one),
    prefixed by the event kind unless the kind is VALUE."""
    names = [name_for_id(f['names'], ev.name_id) for f, ev in events if ev is not None]
    real = [n for n in names if n and n != LVAL_SENTINEL]
    nm = real[0] if real else (names[0] if names else '')
    kind = events[0][1].kind
    kn = KIND_NAMES.get(kind, f'K{kind}')
    if not nm:
        return kn
    return nm if kind == MWK_VALUE else f'{kn} {nm}'


def print_verdict(tally, ungraded, how):
    """THE VERDICT LINE: AGREE + DIVERGE + UNGRADED == the steps compared,
    each UNGRADED name listed with its count -- an UNGRADED step was never
    compared, so it is never a match.  Printed on every exit path once the
    participants are open."""
    n = tally[AGREE] + tally[DIVERGE] + tally[UNGRADED]
    line = (f'[ctrl] VERDICT AGREE={tally[AGREE]} DIVERGE={tally[DIVERGE]} '
            f'UNGRADED={tally[UNGRADED]} of {n} compared step(s) -- {how}')
    if OUTPUT_STATE['fds']:
        mute = [f['name'] for f in OUTPUT_STATE['fds'] if not f['out_capable']]
        line += (f' -- OUTPUT=graded ({len(OUTPUT_STATE["fds"][0]["out"])} byte(s))' if not mute
                 else f' -- OUTPUT=UNGRADED({",".join(mute)} sent no OUTPUT hello: the bytes written were never compared, so output is no part of any AGREE)')
    names = list(ungraded)
    if names:
        shown = ', '.join(f'{nm} x{ungraded[nm][0]}' for nm in names[:UNGRADED_NAMES_SHOWN])
        more = f' (+{len(names) - UNGRADED_NAMES_SHOWN} more)' if len(names) > UNGRADED_NAMES_SHOWN else ''
        line += f'; UNGRADED is never a match: {shown}{more}'
    print(line, file=sys.stderr)
    for nm in names[:UNGRADED_NAMES_SHOWN]:
        cnt, s, stno, cols = ungraded[nm]
        where = f'step {s}' + (f' stno {stno}' if stno is not None else '')
        print(f'[ctrl]   UNGRADED {nm} x{cnt}, first at {where}: {cols}', file=sys.stderr)


OUTPUT_STATE = {'fds': []}


def output_divergence(fds, final=False):
    """None while every participant's output stream agrees with the oracle's up to the shorter one (and, when final, is equal);
    else a one-line description naming the first differing byte. Graded only when every participant said OUTPUT hello."""
    if not fds or not all(f['out_capable'] for f in fds):
        return None
    a = bytes(fds[0]['out'])
    for f in fds[1:]:
        b = bytes(f['out'])
        n = min(len(a), len(b))
        k = next((i for i in range(n) if a[i] != b[i]), None)
        if k is None and final and len(a) != len(b):
            k = n
        if k is not None:
            lo = max(0, k - 24)
            return (f'OUTPUT differs at byte {k}: {fds[0]["name"]} wrote {a[lo:k + 24]!r} ({len(a)} byte(s) so far), '
                    f'{f["name"]} wrote {b[lo:k + 24]!r} ({len(b)} byte(s) so far)')
    return None


def grade_step(events):
    """Grade one lock-step: each non-oracle participant's event against the
    oracle's (events[0]).  DIVERGE if any pair diverges or any side is at
    EOF; else UNGRADED if any pair is ungraded -- or if there is no second
    participant, since then nothing was compared; else AGREE."""
    oracle_f, oracle_ev = events[0]
    if oracle_ev is None:
        return DIVERGE
    if len(events) < 2:
        return UNGRADED
    oracle_key = event_key(oracle_ev, oracle_f['names'])
    oracle_namewild = oracle_f['name'] in WILDCARD_NAMES_PARTICIPANTS
    grade = AGREE
    for f, ev in events[1:]:
        if ev is None:
            return DIVERGE
        g = grade_keys(event_key(ev, f['names']), oracle_key,
                       a_name_wild=f['name'] in WILDCARD_NAMES_PARTICIPANTS,
                       b_name_wild=oracle_namewild)
        if g == DIVERGE:
            return DIVERGE
        if g == UNGRADED:
            grade = UNGRADED
    return grade


# ---------------------------------------------------------------------------
# Pretty-print one event.
# ---------------------------------------------------------------------------

def fmt_value(type_tag, value):
    name = TYPE_NAMES.get(type_tag, f'T{type_tag}')
    if type_tag == 1 or type_tag == 4:  # STRING or NAME
        try:
            s = value.decode('utf-8', errors='backslashreplace')
        except Exception:
            s = repr(value)
        return f'{name}({len(value)})={s!r}'
    if type_tag == 2:  # INTEGER
        if len(value) == 8:
            iv = struct.unpack('<q', value)[0]
            return f'INT={iv}'
        return f'INT(?{len(value)}b)'
    if type_tag == 3:  # REAL
        if len(value) == 8:
            rv = struct.unpack('<d', value)[0]
            return f'REAL={rv!r}'
        return f'REAL(?{len(value)}b)'
    return f'{name}'


def fmt_event(ev, names_table, stno=None):
    kn = KIND_NAMES.get(ev.kind, f'K{ev.kind}')
    nm = name_for_id(names_table, ev.name_id) or '(none)'
    prefix = f'@{stno} ' if stno is not None else ''
    if ev.kind == MWK_END:
        return f'{prefix}{kn}'
    if ev.kind == MWK_CALL:
        return f'{prefix}{kn} {nm}'
    if ev.kind == MWK_RETURN:
        # The SNOBOL4 bridges' payload is the rtntype string ("RETURN"/"FRETURN"/
        # "NRETURN"), not the function result value.  Show as RETURN fname (KIND)
        # to avoid confusion with value-assignment display.  The instrumented
        # oracles (icx, fpx, rkx) and SCRIP's shared return hook send the result
        # itself, typed: that renders as a value, never as raw bytes.
        if ev.type not in (0, 1):
            return f'{prefix}RETURN {nm} = {fmt_value(ev.type, ev.value)}'
        try:
            kind_str = ev.value.decode('utf-8', errors='replace') if ev.value else 'RETURN'
        except Exception:
            kind_str = 'RETURN'
        return f'{prefix}RETURN {nm} ({kind_str})'
    if ev.kind == MWK_LABEL:
        return f'{kn} stno={fmt_value(ev.type, ev.value)}'
    # S-2-bridge-7-byrd-pattern: PM_CALL/EXIT/REDO/FAIL — node-tag + cursor.
    if ev.kind in (MWK_PM_CALL, MWK_PM_EXIT, MWK_PM_REDO, MWK_PM_FAIL):
        return f'{prefix}{kn} {nm} cursor={fmt_value(ev.type, ev.value)}'
    return f'{prefix}{kn} {nm} = {fmt_value(ev.type, ev.value)}'


import re as _re

def _scan_sno(path, inc_dirs, out, visited=None):
    if visited is None: visited = set()
    real = os.path.realpath(path)
    if real in visited: return
    visited.add(real)
    src_dir = os.path.dirname(os.path.abspath(path))
    try: lines = open(path, encoding='utf-8', errors='replace').readlines()
    except OSError: return
    fname = os.path.basename(path)
    for lineno, raw in enumerate(lines, 1):
        t = raw.rstrip('\n')
        if t.startswith('*') or t.startswith('+'): continue
        if t.startswith('-'):
            m = _re.search(r"""['"](.*?)['"]""", t)
            if m and 'INCLUDE' in t[:10].upper():
                for d in [src_dir] + list(inc_dirs):
                    cand = os.path.join(d, m.group(1))
                    if os.path.isfile(cand):
                        _scan_sno(cand, inc_dirs, out, visited); break
            continue
        out['_n'] = out.get('_n', 0) + 1
        out[out['_n']] = (fname, lineno, t.strip())

def build_stno_map():
    sno = os.environ.get('MONITOR_SNO_FILE', '').strip()
    if not sno or not os.path.isfile(sno): return {}
    dirs = [d for d in os.environ.get('MONITOR_INC_DIR', '').split(':') if d]
    raw = {}; _scan_sno(sno, dirs, raw); raw.pop('_n', None)
    return raw  # {int stno: (fname, lineno, stripped_text)}


# ---------------------------------------------------------------------------
# Open one FIFO pair (we read ready, write go).
# ---------------------------------------------------------------------------

class ParticipantNeverStarted(Exception):
    """A participant never opened its end of the FIFO pair within the deadline."""


def open_pair(ready_path, go_path, name='?', deadline_s=None):
    """Open ready FIFO for read, go FIFO for write, REFUSING rather than hanging.

    ⛔⭐ THIS FUNCTION USED TO BE TWO BLOCKING os.open() CALLS AND IT COULD NOT FAIL
    (hq_T 2026-09-09, ceo brief `the-ipc-sync-step-monitor-does-not-run-and-lon-is-
    counting-on-it`).  A FIFO opened O_RDONLY blocks until a WRITER appears, and
    O_WRONLY blocks until a READER appears -- forever, with no timeout of their own.
    So when a participant died during startup, the controller blocked here for the
    whole outer window, printed NOTHING (its first log line comes after the open),
    and the harness sat in `wait` until an external `timeout` killed the process
    group -- whose EXIT trap then deleted the scratch dir holding the answer.

    MEASURED on the ceo's own witness (snoflake `string-pad.sno`): BOTH participants
    had already exited within a second, each having written its reason to its .err
    file, while the controller went on waiting 141s+ for writers that no longer
    existed.  The instrument could not tell "measured and clean" from "never ran" --
    the exact failure the INSTRUMENT LAWS name.

    The read side is opened O_NONBLOCK (which never blocks even with no writer), so
    the deadline is enforced on the WRITE side, where ENXIO means "no reader yet".
    A blown deadline raises ParticipantNeverStarted, which run() turns into an rc=2
    REFUSAL naming the participant -- never a verdict, never a hang.
    """
    if deadline_s is None:
        deadline_s = float(os.environ.get('MONITOR_OPEN_TIMEOUT', '20'))
    # Read side: O_NONBLOCK never blocks on a FIFO opened for read.
    try:
        rd = os.open(ready_path, os.O_RDONLY | os.O_NONBLOCK)
    except OSError as e:
        raise ParticipantNeverStarted(
            f"{name}: cannot open ready FIFO {ready_path}: {e}")
    # Write side: ENXIO until the participant opens its read end.  Poll to a deadline.
    end = time.time() + deadline_s
    gw = None
    while True:
        try:
            gw = os.open(go_path, os.O_WRONLY | os.O_NONBLOCK)
            break
        except OSError as e:
            if e.errno != errno.ENXIO:
                os.close(rd)
                raise ParticipantNeverStarted(
                    f"{name}: cannot open go FIFO {go_path}: {e}")
            if time.time() >= end:
                os.close(rd)
                raise ParticipantNeverStarted(
                    f"{name}: never opened its end of the monitor FIFO pair within "
                    f"{deadline_s:g}s -- its monitor bridge did not fire, or it exited "
                    f"during startup. Check {name}.err in the scratch dir for the reason.")
            time.sleep(0.02)
    # Restore blocking semantics for the steady-state protocol; the deadline above has
    # already proven both ends are open, so a blocking read here cannot hang on a
    # never-started participant.  A participant that dies LATER yields EOF, not a hang.
    for fd in (rd, gw):
        fl = fcntl.fcntl(fd, fcntl.F_GETFL)
        fcntl.fcntl(fd, fcntl.F_SETFL, fl & ~os.O_NONBLOCK)
    return rd, gw


# ---------------------------------------------------------------------------
# Run the controller.
# ---------------------------------------------------------------------------

def run(participants):
    """participants: list of (name, ready_path, go_path)."""
    # Build stno->source map from MONITOR_SNO_FILE + MONITOR_INC_DIR env vars.
    # Pure Python inline read; no sidecar files written; no subprocesses.
    stno_map = build_stno_map()  # {int: (fname, lineno, text)} or {}

    # Optional per-participant wire log — one line per record.  Set
    # MONITOR_TRACE_LOG=/path/prefix and the controller will write
    # /path/prefix.<participant>.log with every record received from each
    # participant in order.  Useful for post-DIVERGE forensic grep without
    # spamming chat.  Empty / unset → no log written.
    trace_prefix = os.environ.get('MONITOR_TRACE_LOG', '').strip()

    fds = []
    for nm, rp, gp in participants:
        # ⛔ REFUSE (rc=2) rather than block forever when a participant never starts.
        # The reason is NAMED here because the controller is the only process that
        # knows which participant it is still waiting for.
        try:
            rd, gw = open_pair(rp, gp, name=nm)
        except ParticipantNeverStarted as e:
            print(f'REFUSING(2) [monitor_sync_bin]: {e}', file=sys.stderr)
            for d in fds:
                try: os.close(d['rd']); os.close(d['gw'])
                except OSError: pass
            return 2
        log_fp = None
        if trace_prefix:
            log_fp = open(f'{trace_prefix}.{nm}.log', 'w')
        fds.append({'name': nm, 'rd': rd, 'gw': gw, 'names': {}, 'out': bytearray(), 'out_capable': False,
                    'log_fp': log_fp})
        print(f'[ctrl] opened {nm}: ready={rp} go={gp}', file=sys.stderr)

    # Interleaved agreed-event trail (circular buffer, always on).
    # Each entry: (step, stno, {pname: event_str}) — one dict per agreed step.
    # On DIVERGE prints as a grid: step | stno | col-per-participant.
    # Buffer is deque(maxlen=N), O(1) append/evict.
    pnames = [nm for nm, rp, gp in participants]
    trail = deque(maxlen=DIVERGE_HISTORY)
    OUTPUT_STATE['fds'] = fds

    # Track last agreed stno from LABEL records so VALUE/CALL/RETURN rows
    # can show which statement they belong to.  The stno is already on the
    # wire — no source file scanning required.
    last_agreed_stno = None

    # The VERDICT line's counts (see print_verdict) and the UNGRADED steps by
    # name: label -> [count, first step, first stno, that step's events].
    tally = {AGREE: 0, DIVERGE: 0, UNGRADED: 0}
    ungraded = {}

    def finish(rc, how):
        print_verdict(tally, ungraded, how)
        return rc

    diverged = False
    how = None
    step = 0

    while True:
        step += 1
        # Read one semantic record from each participant.  read_semantic_record
        # absorbs NAME_DEFs internally (acks them, registers bindings).
        events = []
        eof_set = []
        protocol_err = False
        for f in fds:
            try:
                ev = read_semantic_record(f, EVENT_TIMEOUT_S)
            except ValueError as e:
                print(f'[ctrl] PROTOCOL ERR step {step} on {f["name"]}: {e}', file=sys.stderr)
                protocol_err = True
                events.append((f, None))
                eof_set.append(f['name'])
                continue
            if ev is None:
                events.append((f, None))
                eof_set.append(f['name'])
            else:
                events.append((f, ev))
                if f['log_fp']:
                    f['log_fp'].write(f'#{step} {fmt_event(ev, f["names"], stno=last_agreed_stno)}\n')
                    f['log_fp'].flush()

        if protocol_err:
            for ff in fds:
                try: os.write(ff['gw'], b'S')
                except OSError: pass
            return finish(3, f'PROTOCOL ERR at step {step}')

        # ⛔ THE OUTPUT STREAMS, AT EVERY STEP (see MWK_OUTPUT above): a byte one side wrote that the other wrote differently is the
        # divergence, whatever the paired events say -- located after the last step both agreed on, with both streams named.
        od = output_divergence(fds, final=(len(eof_set) == len(fds) or all(ev is not None and ev.kind == MWK_END for _f, ev in events)))
        if od:
            print(f'\n[ctrl] DIVERGE step {step} (OUTPUT) -- after the last agreed event (stno {last_agreed_stno}): {od}', file=sys.stderr)
            for r in list(trail)[-8:]:
                print(f'[ctrl]   agreed step {r[0]} stno {r[1]}: ' + ' | '.join(f'{k}: {v}' for k, v in r[2].items()), file=sys.stderr)
            for ff in fds:
                try: os.write(ff['gw'], b'S')
                except OSError: pass
            tally[DIVERGE] += 1
            return finish(1, f'DIVERGE at step {step} (OUTPUT)')

        # All EOF: clean termination (legacy path, when a runtime exits without
        # emitting MWK_END).
        if len(eof_set) == len(fds):
            print(f'[ctrl] all reached EOF at step {step} (clean termination)',
                  file=sys.stderr)
            return finish(0, 'all reached EOF')

        # Mixed EOF: divergence in event count.
        if eof_set:
            print(f'[ctrl] PARTIAL EOF step {step}: {eof_set} done, others still running',
                  file=sys.stderr)
            for f, ev in events:
                if ev is not None:
                    print(f'  {f["name"]}: still emitting {fmt_event(ev, f["names"], stno=last_agreed_stno)}',
                          file=sys.stderr)
                else:
                    print(f'  {f["name"]}: EOF', file=sys.stderr)
            for ff in fds:
                try: os.write(ff['gw'], b'S')
                except OSError: pass
            tally[DIVERGE] += 1
            return finish(1, f'PARTIAL EOF at step {step}')

        # Grade the step against the oracle (events[0]) using per-participant
        # name resolution: AGREE, DIVERGE or UNGRADED.  An untyped value
        # (MWT_UNKNOWN) on either side is UNGRADED -- see grade_keys.
        oracle_f, oracle_ev = events[0]
        grade = grade_step(events)
        agree = grade != DIVERGE

        # Opt-in skip — bounded read-ahead on the side(s) that emitted an
        # "extra" VALUE for a keyword (& assignment).  See
        # SKIP_EXTRA_KEYWORD_VALUES comment near the top of this file.
        # Logic: while disagree AND any participant's current event is
        # "VALUE on a name beginning with &", ack that participant only,
        # read its next record, retry comparison.  Bounded to keep us
        # from running ahead unboundedly if the spl gap turns out to be
        # multi-record.
        if not agree and SKIP_EXTRA_KEYWORD_VALUES:
            skip_budget = {f['name']: SKIP_MAX_PER_STEP for f in fds}
            while not agree:
                # Identify participants whose current event is an extra
                # keyword VALUE — i.e., kind == MWK_VALUE and the resolved
                # name starts with '&'.  Only these get advanced.
                advanced_any = False
                for i, (f, ev) in enumerate(events):
                    if ev is None or ev.kind != MWK_VALUE:
                        continue
                    nm = name_for_id(f['names'], ev.name_id)
                    if not nm.startswith('&'):
                        continue
                    if skip_budget[f['name']] <= 0:
                        continue
                    # Ack just this participant, read its next record.
                    try:
                        os.write(f['gw'], b'G')
                    except OSError:
                        return finish(2, f'write failed to {f["name"]} while skipping kw-VALUE at step {step}')
                    try:
                        new_ev = read_semantic_record(f, EVENT_TIMEOUT_S)
                    except ValueError as e:
                        print(f'[ctrl] PROTOCOL ERR while skipping kw-VALUE on {f["name"]}: {e}',
                              file=sys.stderr)
                        return finish(3, f'PROTOCOL ERR at step {step}')
                    if new_ev is None:
                        # EOF on the skipping side mid-skip — let normal
                        # divergence reporting handle it.
                        events[i] = (f, None)
                        break
                    events[i] = (f, new_ev)
                    if f['log_fp']:
                        f['log_fp'].write(f'#{step}+ (kw-VALUE skipped) -> {fmt_event(new_ev, f["names"], stno=last_agreed_stno)}\n')
                        f['log_fp'].flush()
                    skip_budget[f['name']] -= 1
                    advanced_any = True
                if not advanced_any:
                    break  # nothing further to absorb; surface the divergence
                # Regrade with refreshed events.
                oracle_f, oracle_ev = events[0]
                if oracle_ev is None:
                    break
                grade = grade_step(events)
                agree = grade != DIVERGE

        # Opt-in skip — bounded read-ahead on the side(s) whose current LABEL
        # event names a verified bare-label statement (no body).  See
        # SKIP_BARE_LABEL_STNO comment near the top of this file.  Unlike the
        # kw-VALUE skip above, the "behind" side is not necessarily a non-
        # oracle participant — the oracle (spl) is the one that correctly
        # counts the bare-label line as its own statement, so it is usually
        # spl that needs advancing past it.  Logic: while disagree AND any
        # participant's current event is LABEL on a stno that stno_map proves
        # is a bare label token, ack that participant only, read its next
        # record, retry comparison.  A participant already at (or past) the
        # max LABEL stno among current events is never advanced — this only
        # catches genuinely-behind sides, never masks a real forward
        # disagreement.
        if not agree and SKIP_BARE_LABEL_STNO and stno_map:
            skip_budget2 = {f['name']: SKIP_MAX_PER_STEP for f in fds}
            while not agree:
                label_stnos = [_label_stno_of(ev) for _f, ev in events]
                numeric = [s for s in label_stnos if s is not None]
                if not numeric:
                    break  # not a LABEL/LABEL disagreement; nothing this skip can do
                ahead_stno = max(numeric)
                advanced_any = False
                for i, (f, ev) in enumerate(events):
                    s = label_stnos[i]
                    if s is None or s >= ahead_stno:
                        continue  # not behind, or not a LABEL event
                    if not _is_bare_label_stno(stno_map, s):
                        continue  # a real (non-cosmetic) disagreement — do not touch
                    if skip_budget2[f['name']] <= 0:
                        continue
                    try:
                        os.write(f['gw'], b'G')
                    except OSError:
                        return finish(2, f'write failed to {f["name"]} while skipping a bare label at step {step}')
                    try:
                        new_ev = read_semantic_record(f, EVENT_TIMEOUT_S)
                    except ValueError as e:
                        print(f'[ctrl] PROTOCOL ERR while skipping bare-label stno={s} on {f["name"]}: {e}',
                              file=sys.stderr)
                        return finish(3, f'PROTOCOL ERR at step {step}')
                    if new_ev is None:
                        events[i] = (f, None)
                        break
                    events[i] = (f, new_ev)
                    if f['log_fp']:
                        f['log_fp'].write(f'#{step}+ (bare-label stno={s} skipped) -> {fmt_event(new_ev, f["names"], stno=last_agreed_stno)}\n')
                        f['log_fp'].flush()
                    skip_budget2[f['name']] -= 1
                    advanced_any = True
                if not advanced_any:
                    break
                oracle_f, oracle_ev = events[0]
                if oracle_ev is None:
                    break
                grade = grade_step(events)
                agree = grade != DIVERGE

        if not agree:
            div_cols = {f['name']: fmt_event(ev, f['names'], stno=last_agreed_stno)
                        for f, ev in events}
            pnames = [f['name'] for f in fds]
            all_rows = list(trail) + [(step, last_agreed_stno, div_cols, DIVERGE)]
            def src(n):
                if n is None or n not in stno_map: return ''
                fn, ln, txt = stno_map[n]
                return f'{fn}:{ln}  {txt}'
            # Markdown table: | step | stno | p1 | p2 | ... | source |
            def md_row(*cells):
                return '| ' + ' | '.join(str(c) for c in cells) + ' |'
            def md_sep(*widths):
                return '| ' + ' | '.join('-'*max(w,3) for w in widths) + ' |'
            col_w = {p: max(len(p), max((len(r[2].get(p,'')) for r in all_rows), default=0))
                     for p in pnames}
            src_w  = max(6, max((len(src(r[1])) for r in all_rows), default=6))
            step_w = max(4, len(str(step)))
            stno_w = max(4, max((len(str(r[1])) for r in all_rows if r[1] is not None), default=4))
            def row_line(s, n, cols, divrow=False, ungr=False):
                marker = '**>**' if divrow else ('(u)' if ungr else '')
                cells = [marker + str(s), str(n) if n is not None else '']
                cells += [cols.get(p, '') for p in pnames]
                cells += [src(n)]
                return md_row(*cells)
            hdrs = ['step', 'stno'] + pnames + ['source']
            widths = [step_w, stno_w] + [col_w[p] for p in pnames] + [src_w]
            legend = ('; (u) = UNGRADED, never compared'
                      if any(r[3] == UNGRADED for r in trail) else '')
            out = [f'\n[ctrl] DIVERGE step {step} — last {len(trail)} agreed rows + diverge (>){legend}:\n']
            out.append(md_row(*hdrs))
            out.append(md_sep(*widths))
            for i, (s, n, cols, g) in enumerate(all_rows):
                divrow = (i == len(all_rows) - 1)
                out.append(row_line(s, n, cols, divrow, g == UNGRADED))
            print('\n'.join(out), file=sys.stderr)
            for f, ev in events:
                try: os.write(f['gw'], b'S')
                except OSError: pass
            tally[DIVERGE] += 1
            diverged = True
            how = f'DIVERGE at step {step}'
            break
        tally[grade] += 1
        if grade == UNGRADED:
            label = ungraded_label(events)
            if label in ungraded:
                ungraded[label][0] += 1
            else:
                ungraded[label] = [1, step, last_agreed_stno,
                                   ' | '.join(f'{f["name"]}: {fmt_event(ev, f["names"])}'
                                              for f, ev in events)]
        # Update last-agreed stno from LABEL records (stno is on the wire).
        if oracle_ev.kind == MWK_LABEL:
            if len(oracle_ev.value) == 8:
                last_agreed_stno = int.from_bytes(oracle_ev.value, 'little')

        # Store per-participant event strings in the circular trail.
        trail.append((step, last_agreed_stno,
                      {f['name']: fmt_event(ev, f['names'], stno=last_agreed_stno)
                       for f, ev in events}, grade))

        # If everyone sent END, we're done.
        if oracle_ev.kind == MWK_END:
            for f, ev in events:
                try: os.write(f['gw'], b'G')
                except OSError: pass
            print(f'[ctrl] all reached END after {step} steps', file=sys.stderr)
            how = 'all reached END'
            break

        # Otherwise GO to all.
        for f, ev in events:
            try:
                os.write(f['gw'], b'G')
            except OSError:
                print(f'[ctrl] write failed to {f["name"]}', file=sys.stderr)
                diverged = True
                how = f'write failed to {f["name"]} at step {step}'
                break
        if diverged:
            break

    # Close FDs.
    for f in fds:
        try: os.close(f['rd'])
        except OSError: pass
        try: os.close(f['gw'])
        except OSError: pass

    return finish(1 if diverged else 0, how)


def parse_argv(argv):
    """Return participants or exit(2).

    Spec: NAME:READY:GO  (one per participant).  No sidecar/names paths —
    streaming intern means names live on the wire.
    """
    if len(argv) < 2:
        print('Usage: monitor_sync_bin.py NAME:READY:GO ...', file=sys.stderr)
        sys.exit(2)

    participants = []
    for spec in argv[1:]:
        parts = spec.split(':')
        if len(parts) != 3:
            print(f'bad participant spec (expect NAME:READY:GO): {spec}',
                  file=sys.stderr)
            sys.exit(2)
        participants.append(tuple(parts))
    return participants


def main():
    participants = parse_argv(sys.argv)
    rc = run(participants)
    sys.exit(rc)


if __name__ == '__main__':
    main()
