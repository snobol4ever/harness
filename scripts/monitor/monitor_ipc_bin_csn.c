/*
 * monitor_ipc_bin_csn.c — CSNOBOL4 LOAD()able binary sync-step IPC module.
 *
 * Wire protocol: see monitor_wire.h.  All records are pure binary; no
 * string conversion or stringification happens anywhere on the runtime
 * side.  The C code reads the descriptor's type tag and raw bytes
 * directly out of the SCBLK / ICBLK / RCBLK structures.
 *
 * Two FIFOs per participant + one names sidecar:
 *   MONITOR_READY_PIPE     — runtime writes binary records, controller reads
 *   MONITOR_GO_PIPE        — controller writes 1-byte ack ('G' or 'S')
 *   MONITOR_NAMES_FILE     — names table, one name per line, read at MON_OPEN
 *
 * SNOBOL4 entry points (all UPPERCASE — CSNOBOL4 LOAD looks up symbol verbatim):
 *   MON_OPEN(STRING,STRING,STRING)INTEGER         — ready,go,names paths
 *   MON_PUT_CALL(STRING)INTEGER                   — fname
 *   MON_CLOSE()INTEGER
 *
 * Typed value channels — one per SNOBOL4 datatype.  Each declares its second
 * arg with the matching prototype token so the runtime accepts the call
 * without an "argument is not a string" / "Illegal data type" rejection.
 * The wrapper preamble in inject_traces_bin.py dispatches via DATATYPE($N).
 *   MON_PUT_S_VALUE(STRING,STRING)INTEGER         — varname, $N where $N is STRING
 *   MON_PUT_I_VALUE(STRING,INTEGER)INTEGER        — varname, $N where $N is INTEGER
 *   MON_PUT_R_VALUE(STRING,REAL)INTEGER           — varname, $N where $N is REAL
 *   MON_PUT_O_VALUE(STRING,STRING)INTEGER         — varname, type-string for opaque kinds
 *   MON_PUT_S_RETURN(STRING,STRING)INTEGER        — fname,   $F where $F is STRING
 *   MON_PUT_I_RETURN(STRING,INTEGER)INTEGER       — fname,   $F where $F is INTEGER
 *   MON_PUT_R_RETURN(STRING,REAL)INTEGER          — fname,   $F where $F is REAL
 *   MON_PUT_O_RETURN(STRING,STRING)INTEGER        — fname,   type-string for opaque kinds
 *
 * For the OPAQUE channels the second arg carries the runtime-derived
 * datatype name (e.g. "PATTERN", "ARRAY") so the C side can stamp the
 * wire `type` byte correctly without needing block-internal access.
 * The wire `value_len` is always 0 for opaque kinds — type alone matters.
 *
 * MON_PUT_VALUE / MON_PUT_RETURN are kept as legacy polymorphic entry
 * points but are no longer invoked by the injected preamble; they are
 * left in place for direct C-side test programs.
 *
 * Build:
 *   gcc -shared -fPIC -O2 -Wall -o monitor_ipc_bin_csn.so monitor_ipc_bin_csn.c
 */

#include "monitor_wire.h"

#include <fcntl.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <sys/uio.h>

/*============================================================================
 * CSNOBOL4 ABI shape — matches struct descr in include/load.h.
 *==========================================================================*/
typedef long      int_t;
typedef double    real_t;

struct descr {
    union { int_t i; real_t f; } a;
    char         f;
    unsigned int v;
};

#define DESCR_SZ   ((int)sizeof(struct descr))
#define BCDFLD     (4 * DESCR_SZ)

#define LOAD_PROTO  struct descr *retval, unsigned nargs, struct descr *args
#define LA_ALIST    LOAD_PROTO
typedef int lret_t;

#define TRUE  1
#define FALSE 0

/* CSNOBOL4 type tag codes from equ.h.  Verified against /home/claude/csnobol4/equ.h:
 *   S=1 STRING   B=2 ?       P=3 PATTERN   A=4 ARRAY    T=5 TABLE
 *   I=6 INTEGER  R=7 REAL    C=8 CODE      N=9 NAME     K=10 ?
 *   E=11 EXTERNAL  L=12 ?    M=14 (malloc'd string)
 *
 * The descriptor's v field for a STRING-typed cell holds the length of
 * the SCBLK; for INTEGER, v is 0 and a.i is the int value; for REAL,
 * v is 0 and a.f is the double value.  STRING SCBLKs are pointed to by
 * a.i and have a 4*DESCR-byte header before the bytes start (BCDFLD).
 */
#define CSN_T_STRING    1
#define CSN_T_PATTERN   3
#define CSN_T_ARRAY     4
#define CSN_T_TABLE     5
#define CSN_T_INTEGER   6
#define CSN_T_REAL      7
#define CSN_T_CODE      8
#define CSN_T_NAME      9
#define CSN_T_EXTERNAL 11

/* Pointer-to-block helpers: for STRING/NAME the arg's a.i is a pointer to
 * a struct descr that holds the SCBLK header at offset BCDFLD = 4*DESCR. */
static inline void *_blk(int n, struct descr *args) {
    return (void *)(args[n].a.i);
}
static inline int _slen(int n, struct descr *args) {
    void *blk = _blk(n, args);
    if (!blk) return 0;
    return (int)((struct descr *)blk)->v;
}
static inline const char *_sptr(int n, struct descr *args) {
    void *blk = _blk(n, args);
    if (!blk) return NULL;
    return (const char *)blk + BCDFLD;
}

extern void retstring(struct descr *retval, const char *cp, int len);

#define RETINT(N)  do { retval->a.i = (int_t)(N); retval->f = 0; retval->v = CSN_T_INTEGER; return TRUE; } while (0)
#define RETFAIL    return FALSE

static int copy_str_arg(int n, char *buf, int bufsz, struct descr *args) {
    int len = _slen(n, args);
    const char *ptr = _sptr(n, args);
    if (len < 0 || len >= bufsz) return -1;
    if (ptr && len > 0) memcpy(buf, ptr, len);
    buf[len] = '\0';
    return 0;
}

/*============================================================================
 * Module state.
 *==========================================================================*/
static int   g_ready_fd  = -1;
static int   g_go_fd     = -1;

/* Names table — built once at MON_OPEN, never touched after.
 * Parallel arrays so we keep one malloc per name. */
static char **g_names    = NULL;
static int   *g_name_lens= NULL;
static int    g_n_names  = 0;

/*============================================================================
 * Names file load — one name per line.
 *==========================================================================*/
static int load_names_file(const char *path) {
    FILE *f = fopen(path, "r");
    if (!f) return -1;

    int   cap     = 64;
    char **names  = (char **)malloc(cap * sizeof(char *));
    int   *lens   = (int  *)malloc(cap * sizeof(int));
    if (!names || !lens) { fclose(f); free(names); free(lens); return -1; }

    int n = 0;
    char *line = NULL; size_t lcap = 0;
    ssize_t got;
    while ((got = getline(&line, &lcap, f)) >= 0) {
        if (got > 0 && line[got-1] == '\n') { line[got-1] = '\0'; got--; }
        if (got > 0 && line[got-1] == '\r') { line[got-1] = '\0'; got--; }
        if (n == cap) {
            cap *= 2;
            names = (char **)realloc(names, cap * sizeof(char *));
            lens  = (int  *)realloc(lens,  cap * sizeof(int));
            if (!names || !lens) { fclose(f); free(line); return -1; }
        }
        char *copy = (char *)malloc((size_t)got + 1);
        if (!copy) { fclose(f); free(line); return -1; }
        memcpy(copy, line, (size_t)got + 1);
        names[n] = copy;
        lens[n]  = (int)got;
        n++;
    }
    free(line);
    fclose(f);

    g_names     = names;
    g_name_lens = lens;
    g_n_names   = n;
    return 0;
}

/* Linear scan — names tables are small (tens to low-hundreds).
 * Returns name_id or MW_NAME_ID_NONE if not found. */
static uint32_t lookup_name_id(const char *p, int len) {
    if (!g_names) return MW_NAME_ID_NONE;
    for (int i = 0; i < g_n_names; i++) {
        if (g_name_lens[i] == len && memcmp(g_names[i], p, (size_t)len) == 0)
            return (uint32_t)i;
    }
    return MW_NAME_ID_NONE;
}

/*============================================================================
 * Type tag mapping: CSNOBOL4 internal → wire type code.
 *==========================================================================*/
static uint8_t csn_tag_to_wire(unsigned int v) {
    switch (v) {
        case CSN_T_STRING:   return MWT_STRING;
        case CSN_T_INTEGER:  return MWT_INTEGER;
        case CSN_T_REAL:     return MWT_REAL;
        case CSN_T_PATTERN:  return MWT_PATTERN;
        case CSN_T_NAME:     return MWT_NAME;
        case CSN_T_ARRAY:    return MWT_ARRAY;
        case CSN_T_TABLE:    return MWT_TABLE;
        case CSN_T_CODE:     return MWT_CODE;
        case CSN_T_EXTERNAL: return MWT_DATA;  /* user-DATA stored as EXTERNAL */
        case 0:              return MWT_NULL;
        default:             return MWT_UNKNOWN;
    }
}

/*============================================================================
 * Block-and-ack: write iovec to ready fd, read 1-byte ack.
 * Returns 1 on 'G' (go), 0 on 'S' (stop) or any error.
 *==========================================================================*/
static int wait_ack(void) {
    if (g_go_fd < 0) return 0;
    char ack;
    ssize_t r = read(g_go_fd, &ack, 1);
    if (r != 1) return 0;
    return (ack != 'S');
}

/*============================================================================
 * Emit a record: header + value bytes, then block on ack.
 *==========================================================================*/
static int emit_record(uint32_t kind, uint32_t name_id, uint8_t type,
                       const void *value, uint32_t value_len)
{
    if (g_ready_fd < 0) return 0;
    unsigned char hdr[MW_HDR_BYTES];
    mw_pack_hdr(hdr, kind, name_id, type, value_len);

    struct iovec iov[2];
    int niov = 1;
    iov[0].iov_base = hdr;
    iov[0].iov_len  = MW_HDR_BYTES;
    if (value_len > 0 && value) {
        iov[1].iov_base = (void *)value;
        iov[1].iov_len  = (size_t)value_len;
        niov = 2;
    }

    ssize_t total = (ssize_t)MW_HDR_BYTES + (ssize_t)value_len;
    ssize_t got   = writev(g_ready_fd, iov, niov);
    if (got != total) return 0;
    return wait_ack();
}

/*============================================================================
 * Inspect arg n (varargs cell holding the value of $name) and emit a record.
 *==========================================================================*/
static int emit_value(uint32_t kind, uint32_t name_id, struct descr *args, int idx)
{
    unsigned int v = args[idx].v;
    uint8_t type = csn_tag_to_wire(v);

    /* Default: empty value bytes. */
    const void *vp  = NULL;
    uint32_t    vlen = 0;
    int_t  i_buf;
    real_t r_buf;

    switch (type) {
        case MWT_STRING:
        case MWT_NAME:
            vp   = _sptr(idx, args);
            vlen = (uint32_t)_slen(idx, args);
            if (vlen == 0) vp = NULL;
            break;
        case MWT_INTEGER: {
            /* CSNOBOL4 stores int in args[idx].a.i; emit 8 LE bytes. */
            int_t iv = args[idx].a.i;
            unsigned char *p = (unsigned char *)&i_buf;
            for (int k = 0; k < 8; k++) p[k] = (unsigned char)((iv >> (k*8)) & 0xff);
            vp = &i_buf; vlen = 8;
            break;
        }
        case MWT_REAL: {
            /* CSNOBOL4 stores double in args[idx].a.f.  IEEE754; copy raw. */
            real_t rv = args[idx].a.f;
            memcpy(&r_buf, &rv, sizeof(r_buf));
            vp = &r_buf; vlen = 8;
            break;
        }
        default:
            /* PATTERN, ARRAY, TABLE, CODE, EXTERNAL, NULL, UNKNOWN → empty. */
            break;
    }
    return emit_record(kind, name_id, type, vp, vlen);
}

/*============================================================================
 * MON_OPEN(ready_path, go_path, names_path) → 0 on success, FAIL on error.
 *==========================================================================*/
lret_t MON_OPEN(LA_ALIST) {
    char ready_path[4096];
    char go_path[4096];
    char names_path[4096];

    (void)nargs;
    if (copy_str_arg(0, ready_path, sizeof(ready_path), args) < 0) RETFAIL;
    if (copy_str_arg(1, go_path,    sizeof(go_path),    args) < 0) RETFAIL;
    if (copy_str_arg(2, names_path, sizeof(names_path), args) < 0) RETFAIL;
    if (!ready_path[0] || !go_path[0] || !names_path[0]) RETFAIL;

    /* Reset module state. */
    if (g_ready_fd >= 0) { close(g_ready_fd); g_ready_fd = -1; }
    if (g_go_fd    >= 0) { close(g_go_fd);    g_go_fd    = -1; }
    if (g_names) {
        for (int i = 0; i < g_n_names; i++) free(g_names[i]);
        free(g_names); free(g_name_lens);
        g_names = NULL; g_name_lens = NULL; g_n_names = 0;
    }

    if (load_names_file(names_path) < 0) RETFAIL;

    /* Ready pipe: write end, non-blocking-then-blocking. */
    g_ready_fd = open(ready_path, O_WRONLY | O_NONBLOCK);
    if (g_ready_fd < 0) g_ready_fd = open(ready_path, O_WRONLY);
    if (g_ready_fd < 0) RETFAIL;

    /* Go pipe: read end, O_NONBLOCK to avoid deadlock then clear. */
    g_go_fd = open(go_path, O_RDONLY | O_NONBLOCK);
    if (g_go_fd < 0) { close(g_ready_fd); g_ready_fd = -1; RETFAIL; }
    { int fl = fcntl(g_go_fd, F_GETFL);
      fcntl(g_go_fd, F_SETFL, fl & ~O_NONBLOCK); }

    RETINT(0);
}

/*============================================================================
 * MON_PUT_VALUE(name, $name) — name is arg 0 (always STRING),
 * $name is arg 1 (any type).  Returns 0 on GO, FAIL on STOP.
 *==========================================================================*/
lret_t MON_PUT_VALUE(LA_ALIST) {
    (void)nargs;
    int    nlen = _slen(0, args);
    const char *nptr = _sptr(0, args);
    if (!nptr) RETFAIL;

    uint32_t name_id = lookup_name_id(nptr, nlen);
    if (name_id == MW_NAME_ID_NONE) RETFAIL;

    if (!emit_value(MWK_VALUE, name_id, args, 1)) RETFAIL;
    RETINT(0);
}

/*============================================================================
 * MON_PUT_CALL(name) — emits a CALL event, no value.
 *==========================================================================*/
lret_t MON_PUT_CALL(LA_ALIST) {
    (void)nargs;
    int    nlen = _slen(0, args);
    const char *nptr = _sptr(0, args);
    if (!nptr) RETFAIL;

    uint32_t name_id = lookup_name_id(nptr, nlen);
    if (name_id == MW_NAME_ID_NONE) RETFAIL;

    if (!emit_record(MWK_CALL, name_id, MWT_NULL, NULL, 0)) RETFAIL;
    RETINT(0);
}

/*============================================================================
 * MON_PUT_RETURN(name, $name) — emits a RETURN event with the function's
 * return-value descriptor as the value field.
 *==========================================================================*/
lret_t MON_PUT_RETURN(LA_ALIST) {
    (void)nargs;
    int    nlen = _slen(0, args);
    const char *nptr = _sptr(0, args);
    if (!nptr) RETFAIL;

    uint32_t name_id = lookup_name_id(nptr, nlen);
    if (name_id == MW_NAME_ID_NONE) RETFAIL;

    if (!emit_value(MWK_RETURN, name_id, args, 1)) RETFAIL;
    RETINT(0);
}

/*============================================================================
 * Typed value/return entry points — one per dialect datatype.
 *
 * All four (S/I/R/O) follow the same shape:
 *   1) lookup name_id from arg 0
 *   2) emit a fixed-type record from arg 1
 *
 * For STRING/INTEGER/REAL: arg 1 IS the value descriptor; emit_record
 * with raw value bytes copied off args[1].
 * For OPAQUE: arg 1 is a STRING naming the opaque type; we map it to
 * MWT_PATTERN / MWT_ARRAY / etc. and emit (type, len=0).
 *==========================================================================*/

/* Internal helpers — emit value of a known type from args[1]. */
static int _put_str_at_idx1(uint32_t kind, uint32_t name_id, struct descr *args) {
    int len = _slen(1, args);
    const char *p = _sptr(1, args);
    if (len < 0) RETFAIL;
    return emit_record(kind, name_id, MWT_STRING, len > 0 ? p : NULL,
                       (uint32_t)(len > 0 ? len : 0)) ? TRUE : FALSE;
}
static int _put_int_at_idx1(uint32_t kind, uint32_t name_id, struct descr *args) {
    /* CSNOBOL4 marshalled INTEGER → args[1].a.i is the long value. */
    int_t iv = args[1].a.i;
    unsigned char buf[8];
    for (int k = 0; k < 8; k++) buf[k] = (unsigned char)((iv >> (k*8)) & 0xff);
    return emit_record(kind, name_id, MWT_INTEGER, buf, 8) ? TRUE : FALSE;
}
static int _put_real_at_idx1(uint32_t kind, uint32_t name_id, struct descr *args) {
    /* CSNOBOL4 marshalled REAL → args[1].a.f is the double value. */
    real_t rv = args[1].a.f;
    unsigned char buf[8];
    memcpy(buf, &rv, 8);
    return emit_record(kind, name_id, MWT_REAL, buf, 8) ? TRUE : FALSE;
}

/* Map a runtime-derived datatype-name string to a wire type code.
 * Comparison is case-insensitive — both dialects' DATATYPE() conventions
 * are accepted.  Returns MWT_UNKNOWN on no match. */
static uint8_t opaque_name_to_wire(const char *p, int len) {
    if (!p || len <= 0) return MWT_UNKNOWN;
    /* Stack copy + uppercase fold for comparison. */
    char buf[16];
    if (len >= (int)sizeof(buf)) return MWT_UNKNOWN;
    for (int i = 0; i < len; i++) {
        char c = p[i];
        if (c >= 'a' && c <= 'z') c = (char)(c - 'a' + 'A');
        buf[i] = c;
    }
    buf[len] = '\0';
    if      (!strcmp(buf, "STRING"))     return MWT_STRING;
    else if (!strcmp(buf, "INTEGER"))    return MWT_INTEGER;
    else if (!strcmp(buf, "REAL"))       return MWT_REAL;
    else if (!strcmp(buf, "NAME"))       return MWT_NAME;
    else if (!strcmp(buf, "PATTERN"))    return MWT_PATTERN;
    else if (!strcmp(buf, "EXPRESSION")) return MWT_EXPRESSION;
    else if (!strcmp(buf, "ARRAY"))      return MWT_ARRAY;
    else if (!strcmp(buf, "TABLE"))      return MWT_TABLE;
    else if (!strcmp(buf, "CODE"))       return MWT_CODE;
    else if (!strcmp(buf, "FILE"))       return MWT_FILE;
    /* Unknown / user-DATA / EXTERNAL etc. → DATA (catch-all opaque). */
    return MWT_DATA;
}

static int _put_opaque_at_idx1(uint32_t kind, uint32_t name_id, struct descr *args) {
    int len = _slen(1, args);
    const char *p = _sptr(1, args);
    uint8_t type = opaque_name_to_wire(p, len);
    return emit_record(kind, name_id, type, NULL, 0) ? TRUE : FALSE;
}

/* Resolve arg 0 → name_id, fail cleanly if missing. */
static int _resolve_name_id(struct descr *args, uint32_t *out_id) {
    int nlen = _slen(0, args);
    const char *nptr = _sptr(0, args);
    if (!nptr) return FALSE;
    uint32_t id = lookup_name_id(nptr, nlen);
    if (id == MW_NAME_ID_NONE) return FALSE;
    *out_id = id;
    return TRUE;
}

/* VALUE channel — typed. */
lret_t MON_PUT_S_VALUE(LA_ALIST) {
    (void)nargs;
    uint32_t name_id;
    if (!_resolve_name_id(args, &name_id)) RETFAIL;
    if (!_put_str_at_idx1(MWK_VALUE, name_id, args)) RETFAIL;
    RETINT(0);
}
lret_t MON_PUT_I_VALUE(LA_ALIST) {
    (void)nargs;
    uint32_t name_id;
    if (!_resolve_name_id(args, &name_id)) RETFAIL;
    if (!_put_int_at_idx1(MWK_VALUE, name_id, args)) RETFAIL;
    RETINT(0);
}
lret_t MON_PUT_R_VALUE(LA_ALIST) {
    (void)nargs;
    uint32_t name_id;
    if (!_resolve_name_id(args, &name_id)) RETFAIL;
    if (!_put_real_at_idx1(MWK_VALUE, name_id, args)) RETFAIL;
    RETINT(0);
}
lret_t MON_PUT_O_VALUE(LA_ALIST) {
    (void)nargs;
    uint32_t name_id;
    if (!_resolve_name_id(args, &name_id)) RETFAIL;
    if (!_put_opaque_at_idx1(MWK_VALUE, name_id, args)) RETFAIL;
    RETINT(0);
}

/* RETURN channel — typed. */
lret_t MON_PUT_S_RETURN(LA_ALIST) {
    (void)nargs;
    uint32_t name_id;
    if (!_resolve_name_id(args, &name_id)) RETFAIL;
    if (!_put_str_at_idx1(MWK_RETURN, name_id, args)) RETFAIL;
    RETINT(0);
}
lret_t MON_PUT_I_RETURN(LA_ALIST) {
    (void)nargs;
    uint32_t name_id;
    if (!_resolve_name_id(args, &name_id)) RETFAIL;
    if (!_put_int_at_idx1(MWK_RETURN, name_id, args)) RETFAIL;
    RETINT(0);
}
lret_t MON_PUT_R_RETURN(LA_ALIST) {
    (void)nargs;
    uint32_t name_id;
    if (!_resolve_name_id(args, &name_id)) RETFAIL;
    if (!_put_real_at_idx1(MWK_RETURN, name_id, args)) RETFAIL;
    RETINT(0);
}
lret_t MON_PUT_O_RETURN(LA_ALIST) {
    (void)nargs;
    uint32_t name_id;
    if (!_resolve_name_id(args, &name_id)) RETFAIL;
    if (!_put_opaque_at_idx1(MWK_RETURN, name_id, args)) RETFAIL;
    RETINT(0);
}

/*============================================================================
 * MON_CLOSE() — emits END event then closes pipes.
 *==========================================================================*/
lret_t MON_CLOSE(LA_ALIST) {
    (void)nargs; (void)args;
    if (g_ready_fd >= 0) {
        emit_record(MWK_END, MW_NAME_ID_NONE, MWT_NULL, NULL, 0);
        close(g_ready_fd); g_ready_fd = -1;
    }
    if (g_go_fd >= 0) { close(g_go_fd); g_go_fd = -1; }
    if (g_names) {
        for (int i = 0; i < g_n_names; i++) free(g_names[i]);
        free(g_names); free(g_name_lens);
        g_names = NULL; g_name_lens = NULL; g_n_names = 0;
    }
    RETINT(0);
}
