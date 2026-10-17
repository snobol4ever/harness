#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/uio.h>
#include "monitor_ipc_lib.h"
static int      g_ready_fd       = -1;
static int      g_go_fd          = -1;
static int      g_init_attempted = 0;
static int      g_init_ok        = 0;
static int      g_atexit_done    = 0;
static int      g_in_emit        = 0;
static int      g_speaks_output  = 0;
static int      g_output_hello   = 0;
static char   **g_names          = NULL;
static int     *g_name_lens      = NULL;
static int      g_n_names        = 0;
static int      g_names_cap      = 0;
static void emit_record_raw(uint32_t kind, uint32_t name_id, uint8_t type, const void *value, uint32_t value_len);
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static void mw_pack_hdr(unsigned char hdr[MW_HDR_BYTES], uint32_t kind, uint32_t name_id, uint8_t type, uint32_t value_len)
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
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static void monitor_atexit(void)
{
    if (g_atexit_done) return;
    g_atexit_done = 1;
    if (g_init_ok && g_ready_fd >= 0) emit_record_raw(MWK_END, MW_NAME_ID_NONE, MWT_NULL, NULL, 0);
    if (g_ready_fd >= 0) { close(g_ready_fd); g_ready_fd = -1; }
    if (g_go_fd    >= 0) { close(g_go_fd);    g_go_fd    = -1; }
}
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static int monitor_init(void)
{
    if (g_init_attempted) return g_init_ok;
    g_init_attempted = 1;
    const char *ready_path = getenv("MONITOR_READY_PIPE");
    const char *go_path    = getenv("MONITOR_GO_PIPE");
    if (!ready_path || !*ready_path) return 0;
    if (!go_path    || !*go_path)    return 0;
    int rfd = open(ready_path, O_WRONLY | O_NONBLOCK);
    if (rfd < 0) rfd = open(ready_path, O_WRONLY);
    if (rfd < 0) return 0;
    int rfl = fcntl(rfd, F_GETFL, 0);
    if (rfl >= 0) fcntl(rfd, F_SETFL, rfl & ~O_NONBLOCK);
    int gfd = open(go_path, O_RDONLY);
    if (gfd < 0) { close(rfd); return 0; }
    g_ready_fd = rfd;
    g_go_fd    = gfd;
    g_init_ok  = 1;
    atexit(monitor_atexit);
    if (g_speaks_output && !g_output_hello) { g_output_hello = 1; emit_record_raw(MWK_OUTPUT, MW_OUTPUT_HELLO, MWT_NULL, NULL, 0); }
    return 1;
}
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int mon_ipc_live(void) { return monitor_init(); }
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static int wait_ack(void)
{
    if (g_go_fd < 0) return 0;
    char ack;
    ssize_t r = read(g_go_fd, &ack, 1);
    if (r != 1) return 0;
    return (ack != 'S');
}
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static void emit_record_raw(uint32_t kind, uint32_t name_id, uint8_t type, const void *value, uint32_t value_len)
{
    if (g_ready_fd < 0) return;
    unsigned char hdr[MW_HDR_BYTES];
    mw_pack_hdr(hdr, kind, name_id, type, value_len);
    struct iovec iov[2];
    int niov = 1;
    iov[0].iov_base = hdr;
    iov[0].iov_len  = MW_HDR_BYTES;
    if (value_len > 0 && value) { iov[1].iov_base = (void *)value; iov[1].iov_len = (size_t)value_len; niov = 2; }
    ssize_t total = (ssize_t)MW_HDR_BYTES + (ssize_t)value_len;
    ssize_t got   = writev(g_ready_fd, iov, niov);
    if (got != total) return;
    if (kind != MWK_END) (void)wait_ack();
}
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static uint32_t intern_name(const char *p, uint32_t len)
{
    if (!p) return MW_NAME_ID_NONE;
    for (int i = 0; i < g_n_names; i++)
        if ((uint32_t)g_name_lens[i] == len && (len == 0 || memcmp(g_names[i], p, (size_t)len) == 0)) return (uint32_t)i;
    if (g_n_names == g_names_cap) {
        int nc = g_names_cap ? g_names_cap * 2 : 64;
        char **nn = (char **)realloc(g_names,    (size_t)nc * sizeof(char *));
        int   *nl = (int  *)realloc(g_name_lens, (size_t)nc * sizeof(int));
        if (!nn || !nl) { free(nn); free(nl); return MW_NAME_ID_NONE; }
        g_names = nn; g_name_lens = nl; g_names_cap = nc;
    }
    char *copy = (char *)malloc((size_t)len + 1);
    if (!copy) return MW_NAME_ID_NONE;
    if (len > 0) memcpy(copy, p, (size_t)len);
    copy[len] = '\0';
    uint32_t id = (uint32_t)g_n_names;
    g_names[g_n_names] = copy; g_name_lens[g_n_names] = (int)len; g_n_names++;
    if (g_init_ok && g_ready_fd >= 0) emit_record_raw(MWK_NAME_DEF, id, MWT_STRING, (len > 0) ? (const void *)copy : NULL, len);
    return id;
}
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
void mon_ipc_int_bytes(int64_t v, unsigned char out[8]) { for (int k = 0; k < 8; k++) out[k] = (unsigned char)(((uint64_t)v >> (k*8)) & 0xff); }
void mon_ipc_real_bytes(double v, unsigned char out[8]) { memcpy(out, &v, 8); }
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
void mon_ipc_stmt(int64_t line)
{
    if (!monitor_init() || g_in_emit) return;
    g_in_emit = 1;
    unsigned char buf[8]; mon_ipc_int_bytes(line, buf);
    emit_record_raw(MWK_LABEL, MW_NAME_ID_NONE, MWT_INTEGER, buf, 8);
    g_in_emit = 0;
}
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
void mon_ipc_call(const char *name, uint32_t len)
{
    if (!monitor_init() || g_in_emit || !name) return;
    g_in_emit = 1;
    uint32_t id = intern_name(name, len);
    if (id != MW_NAME_ID_NONE) emit_record_raw(MWK_CALL, id, MWT_NULL, NULL, 0);
    g_in_emit = 0;
}
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
void mon_ipc_return(const char *name, uint32_t len, uint8_t type, const void *val, uint32_t vlen)
{
    if (!monitor_init() || g_in_emit || !name) return;
    g_in_emit = 1;
    uint32_t id = intern_name(name, len);
    if (id != MW_NAME_ID_NONE) emit_record_raw(MWK_RETURN, id, type, val, vlen);
    g_in_emit = 0;
}
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
void mon_ipc_value(const char *name, uint32_t len, uint8_t type, const void *val, uint32_t vlen)
{
    if (!monitor_init() || g_in_emit || !name) return;
    g_in_emit = 1;
    uint32_t id = intern_name(name, len);
    if (id != MW_NAME_ID_NONE) emit_record_raw(MWK_VALUE, id, type, val, vlen);
    g_in_emit = 0;
}
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
void mon_ipc_speak_output(void)
{
    g_speaks_output = 1;
    if (g_init_ok && g_ready_fd >= 0 && !g_output_hello) { g_output_hello = 1; emit_record_raw(MWK_OUTPUT, MW_OUTPUT_HELLO, MWT_NULL, NULL, 0); }
}
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
void mon_ipc_output(const char *bytes, uint32_t len)
{
    if (!len || !bytes || !monitor_init() || g_in_emit) return;
    g_in_emit = 1;
    if (!g_output_hello) mon_ipc_speak_output();
    emit_record_raw(MWK_OUTPUT, MW_NAME_ID_NONE, MWT_STRING, bytes, len);
    g_in_emit = 0;
}
