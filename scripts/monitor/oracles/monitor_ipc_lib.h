#ifndef MONITOR_IPC_LIB_H
#define MONITOR_IPC_LIB_H
#include <stdint.h>
#define MWK_VALUE       1u
#define MWK_CALL        2u
#define MWK_RETURN      3u
#define MWK_END         4u
#define MWK_LABEL       5u
#define MWK_NAME_DEF    6u
#define MWK_OUTPUT     11u
#define MW_OUTPUT_HELLO 0xfffffffeu
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
#define MWT_UNKNOWN   255
#define MW_HDR_BYTES    13
#define MW_NAME_ID_NONE 0xffffffffu
int  mon_ipc_live(void);
void mon_ipc_stmt(int64_t line);
void mon_ipc_call(const char *name, uint32_t len);
void mon_ipc_return(const char *name, uint32_t len, uint8_t type, const void *val, uint32_t vlen);
void mon_ipc_value(const char *name, uint32_t len, uint8_t type, const void *val, uint32_t vlen);
void mon_ipc_speak_output(void);
void mon_ipc_output(const char *bytes, uint32_t len);
void mon_ipc_int_bytes(int64_t v, unsigned char out[8]);
void mon_ipc_real_bytes(double v, unsigned char out[8]);
#endif
