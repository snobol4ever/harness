/*
 * monitor_wire.h — sync-step monitor binary wire format.
 *
 * Single source of truth for the binary record layout used by:
 *   - ../harness/scripts/monitor/monitor_ipc_bin_csn.c   (CSNOBOL4 ABI)
 *   - x64/monitor_ipc_bin_spl.c               (SPITBOL ABI)
 *   - src/runtime/x86/snobol4.c mon_send      (scrip in-process)
 *   - ../harness/scripts/monitor/monitor_sync.py         (controller)
 *
 * Wire format — fixed 13-byte header, optional value bytes:
 *
 *   offset  size  field        notes
 *   ------  ----  -----------  ----------------------------------------
 *      0     4    kind         u32 LE: 1=VALUE 2=CALL 3=RETURN 4=END 5=LABEL 6=NAME_DEF
 *      4     4    name_id      u32 LE: streaming-intern id (see MWK_NAME_DEF)
 *      8     1    type         u8: SNOBOL4 datatype, see MWT_*
 *      9     4    value_len    u32 LE: length of value_bytes that follow
 *     13   ...    value_bytes  raw bytes per type:
 *                                STRING / NAME    : raw bytes, length=value_len
 *                                INTEGER          : 8 bytes int64 LE, length=8
 *                                REAL             : 8 bytes IEEE754 double LE, length=8
 *                                NULL / PATTERN /
 *                                ARRAY / TABLE /
 *                                CODE / DATA /
 *                                EXPRESSION / FILE: empty, length=0
 *
 * Cross-dialect comparison is byte-for-byte equality on the full record.
 *
 * MWK_LABEL semantics: emitted by the runtime on every statement entry
 * (one per source statement, regardless of GOTO / fall-through).  The
 * name_id is MW_NAME_ID_NONE; the type is MWT_INTEGER and the 8-byte LE
 * payload carries the SNOBOL4 statement number (&STNO) of the statement
 * being entered.  Controllers align on STNO alignment without needing
 * a label-table reverse lookup; the source line / label name (if any)
 * can be derived externally from the program listing.
 *
 * MWK_NAME_DEF semantics (SN-26-bridge-coverage-e — streaming intern):
 * emitted by the runtime IMMEDIATELY BEFORE the first record that
 * references a given name_id.  The runtime maintains a private intern
 * table; when a name is interned for the first time, a NAME_DEF record
 * is sent giving the binding name_id -> name bytes:
 *     kind      = MWK_NAME_DEF
 *     name_id   = the id being defined
 *     type      = MWT_STRING
 *     value_len = length of the name in bytes
 *     value     = the name bytes (UTF-8)
 * Subsequent records may use this name_id without re-emitting the name.
 * Receivers build a per-participant intern table from these wire records;
 * NO sidecar file is read or written.  NAME_DEF records ARE acked by the
 * controller (sync-step discipline) but are NOT considered semantic events
 * for divergence comparison — different participants may intern the same
 * name at different ids without diverging, since the controller resolves
 * each record's name_id to a name string before the (kind,name,type,value)
 * comparison.  An END record always carries name_id = MW_NAME_ID_NONE and
 * is never preceded by a NAME_DEF for that id.
 */

#ifndef MONITOR_WIRE_H
#define MONITOR_WIRE_H

#include <stdint.h>

/* --- Event kinds (record.kind) -------------------------------------------- */
#define MWK_VALUE     1u
#define MWK_CALL      2u
#define MWK_RETURN    3u
#define MWK_END       4u
#define MWK_LABEL     5u   /* statement entry — carries STNO label name (or empty) */
#define MWK_NAME_DEF  6u   /* SN-26-bridge-coverage-e: streaming-intern name binding */
/* Byrd-box pattern-match traversal events (S-2-bridge-7-byrd-pattern).
 * Each fires per AST-node Match attempt:
 *   PM_CALL — Match() entered for node                 (forward, new attempt)
 *   PM_EXIT — node Scan returned SUCCESS               (forward, advancing to subsequent)
 *   PM_REDO — RestoreAlternate popped this node        (backward, retry from saved cursor)
 *   PM_FAIL — node FAILED, no alternate restored       (backward, propagating outward)
 * The name field carries a node-tag string (e.g. *snoString, BREAK, LITERAL);
 * type=MWT_INTEGER, value=8-byte LE cursor position.  Comparison: (kind, name, cursor). */
#define MWK_PM_CALL   7u
#define MWK_PM_EXIT   8u
#define MWK_PM_REDO   9u
#define MWK_PM_FAIL  10u

/* --- SNOBOL4 datatype codes (record.type) --------------------------------- */
/* Chosen as a stable, dialect-neutral enumeration.  Both ABIs map their
 * internal type tags to these on emit; the controller never sees the
 * dialect-specific tags. */
#define MWT_NULL        0
#define MWT_STRING      1
#define MWT_INTEGER     2
#define MWT_REAL        3
#define MWT_NAME        4
#define MWT_PATTERN     5
#define MWT_EXPRESSION  6
#define MWT_ARRAY       7
#define MWT_TABLE       8
#define MWT_CODE        9
#define MWT_DATA       10
#define MWT_FILE       11
#define MWT_UNKNOWN   255   /* fallback for ABI-specific tags we don't decode */

/* --- Header on the wire is exactly 13 bytes ------------------------------- */
#define MW_HDR_BYTES   13

/* --- Reserved name_id for END events (no associated name) ----------------- */
#define MW_NAME_ID_NONE  0xffffffffu

/* --- Helpers to build a header in a stack buffer -------------------------- */
/* Caller provides a 13-byte buffer; this writes the header in LE byte order
 * regardless of host endianness.  Returns nothing — caller knows the size. */
static inline void mw_pack_hdr(unsigned char hdr[MW_HDR_BYTES],
                               uint32_t kind, uint32_t name_id,
                               uint8_t  type, uint32_t value_len)
{
    hdr[0]  = (unsigned char)( kind        & 0xff);
    hdr[1]  = (unsigned char)((kind  >>  8)& 0xff);
    hdr[2]  = (unsigned char)((kind  >> 16)& 0xff);
    hdr[3]  = (unsigned char)((kind  >> 24)& 0xff);
    hdr[4]  = (unsigned char)( name_id      & 0xff);
    hdr[5]  = (unsigned char)((name_id>>  8)& 0xff);
    hdr[6]  = (unsigned char)((name_id>> 16)& 0xff);
    hdr[7]  = (unsigned char)((name_id>> 24)& 0xff);
    hdr[8]  = type;
    hdr[9]  = (unsigned char)( value_len      & 0xff);
    hdr[10] = (unsigned char)((value_len>>  8)& 0xff);
    hdr[11] = (unsigned char)((value_len>> 16)& 0xff);
    hdr[12] = (unsigned char)((value_len>> 24)& 0xff);
}

#endif /* MONITOR_WIRE_H */
