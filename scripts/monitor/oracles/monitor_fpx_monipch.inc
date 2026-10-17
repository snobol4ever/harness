{
    monipch.inc -- the IPC sync-step monitor's fire-points, interface (the SCRIP fpc-mon fork of Free Pascal).

    The fork's compiler (-gi) injects calls to these compilerprocs at every element of every statement list (fpc_mon_stmt),
    at every user procedure's entry (fpc_mon_call) and exit (fpc_mon_ev_* with kind 3, RETURN), and after every store to a
    named variable (fpc_mon_ev_* with kind 1, VALUE). They speak the SPITBOL fork's monitor wire (monitor_ipc_lib.c in
    harness/scripts/monitor/oracles): named pipes MONITOR_READY_PIPE / MONITOR_GO_PIPE, one 13-byte little-endian header
    (u32 kind | u32 name_id | u8 type | u32 value_len) plus the value bytes per event, a blocking one-byte ack after every
    record (the sync-step), names interned on the wire (MWK_NAME_DEF), MWK_END at exit -- and they are a silent no-op when
    the pipes are unset, so the instrumented binary's untraced behaviour is the pristine compiler's.
}
procedure fpc_mon_stmt(line: longint); compilerproc;
procedure fpc_mon_call(name: pansichar); compilerproc;
procedure fpc_mon_ev_int(kind: longint; name: pansichar; v: int64); compilerproc;
procedure fpc_mon_ev_real(kind: longint; name: pansichar; v: double); compilerproc;
procedure fpc_mon_ev_char(kind: longint; name: pansichar; c: ansichar); compilerproc;
procedure fpc_mon_ev_sstr(kind: longint; name: pansichar; const s: shortstring); compilerproc;
procedure fpc_mon_ev_astr(kind: longint; name: pansichar; const s: ansistring); compilerproc;
procedure fpc_mon_ev_bytes(kind: longint; name: pansichar; p: pointer; len: sizeint); compilerproc;
procedure fpc_mon_ev_enum(kind: longint; name: pansichar; o: int64; names: pansichar); compilerproc;
procedure fpc_mon_ev_none(kind: longint; name: pansichar); compilerproc;
procedure fpc_mon_ev_unknown(kind: longint; name: pansichar); compilerproc;
procedure fpc_mon_end;
