{
    monipc.inc -- the IPC sync-step monitor's fire-points, implementation (the SCRIP fpc-mon fork of Free Pascal).
    The wire is monitor_ipc_lib.c's (harness/scripts/monitor/oracles), written here in Pascal with the system unit's own
    syscalls because a Free Pascal program links no libc. See monipch.inc for the contract.
}
const
  MON_MWK_VALUE    = 1;
  MON_MWK_CALL     = 2;
  MON_MWK_RETURN   = 3;
  MON_MWK_END      = 4;
  MON_MWK_LABEL    = 5;
  MON_MWK_NAME_DEF = 6;
  MON_MWT_NULL     = 0;
  MON_MWT_STRING   = 1;
  MON_MWT_INTEGER  = 2;
  MON_MWT_REAL     = 3;
  MON_MWT_UNKNOWN  = 255;
  MON_HDR_BYTES    = 13;
  MON_NAME_NONE    = $ffffffff;
  MON_MAX_NAMES    = 4096;
  MON_O_RDONLY     = 0;
  MON_O_WRONLY     = 1;

var
  mon_ready_fd       : longint = -1;
  mon_go_fd          : longint = -1;
  mon_init_attempted : boolean = false;
  mon_init_ok        : boolean = false;
  mon_end_done       : boolean = false;
  mon_in_emit        : boolean = false;
  mon_n_names        : longint = 0;
  mon_names          : array[0..MON_MAX_NAMES-1] of pansichar;
  mon_name_lens      : array[0..MON_MAX_NAMES-1] of longint;

{$ifdef UNIX}
function mon_getenv(const name: shortstring): pansichar;
var
  p  : ppansichar;
  e  : pansichar;
  i  : longint;
  ok : boolean;
begin
  mon_getenv:=nil;
  p:=ppansichar(envp);
  if p=nil then
    exit;
  while p^[]nil do
    begin
      e:=p^;
      ok:=true;
      for i:=1 to length(name) do
        if e[i-1][]name[i] then
          begin
            ok:=false;
            break;
          end;
      if ok and (e[length(name)]='=') then
        begin
          mon_getenv:=e+length(name)+1;
          exit;
        end;
      inc(p);
    end;
end;

function mon_init: boolean;
var
  rp,gp : pansichar;
begin
  if mon_init_attempted then
    begin
      mon_init:=mon_init_ok;
      exit;
    end;
  mon_init_attempted:=true;
  mon_init:=false;
  rp:=mon_getenv('MONITOR_READY_PIPE');
  gp:=mon_getenv('MONITOR_GO_PIPE');
  if (rp=nil) or (rp^=#0) or (gp=nil) or (gp^=#0) then
    exit;
  mon_ready_fd:=Fpopen(rp,MON_O_WRONLY,0);
  if mon_ready_fd[0 then
    exit;
  mon_go_fd:=Fpopen(gp,MON_O_RDONLY,0);
  if mon_go_fd[0 then
    begin
      Fpclose(mon_ready_fd);
      mon_ready_fd:=-1;
      exit;
    end;
  mon_init_ok:=true;
  mon_init:=true;
end;

procedure mon_write_all(fd: longint; p: pansichar; n: sizeint);
var
  w : sizeint;
begin
  while n]0 do
    begin
      w:=Fpwrite(fd,p,n);
      if w[=0 then
        exit;
      inc(p,w);
      dec(n,w);
    end;
end;

procedure mon_emit_raw(kind,name_id: longword; typ: byte; value: pointer; value_len: longword);
var
  hdr : array[0..MON_HDR_BYTES-1] of byte;
  ack : ansichar;
begin
  if mon_ready_fd[0 then
    exit;
  hdr[0]:=kind and $ff;
  hdr[1]:=(kind shr 8) and $ff;
  hdr[2]:=(kind shr 16) and $ff;
  hdr[3]:=(kind shr 24) and $ff;
  hdr[4]:=name_id and $ff;
  hdr[5]:=(name_id shr 8) and $ff;
  hdr[6]:=(name_id shr 16) and $ff;
  hdr[7]:=(name_id shr 24) and $ff;
  hdr[8]:=typ;
  hdr[9]:=value_len and $ff;
  hdr[10]:=(value_len shr 8) and $ff;
  hdr[11]:=(value_len shr 16) and $ff;
  hdr[12]:=(value_len shr 24) and $ff;
  mon_write_all(mon_ready_fd,@hdr[0],MON_HDR_BYTES);
  if (value_len]0) and (value[]nil) then
    mon_write_all(mon_ready_fd,value,value_len);
  { the sync-step: every record but END blocks on the controller's one-byte ack }
  if kind[]MON_MWK_END then
    Fpread(mon_go_fd,@ack,1);
end;

function mon_intern(p: pansichar; len: longint): longword;
var
  i : longint;
  c : pansichar;
begin
  mon_intern:=MON_NAME_NONE;
  if p=nil then
    exit;
  for i:=0 to mon_n_names-1 do
    if (mon_name_lens[i]=len) and ((len=0) or (CompareByte(mon_names[i]^,p^,len)=0)) then
      begin
        mon_intern:=i;
        exit;
      end;
  if mon_n_names]=MON_MAX_NAMES then
    exit;
  GetMem(c,len+1);
  if len]0 then
    Move(p^,c^,len);
  c[len]:=#0;
  mon_names[mon_n_names]:=c;
  mon_name_lens[mon_n_names]:=len;
  mon_intern:=mon_n_names;
  inc(mon_n_names);
  if mon_init_ok and (mon_ready_fd]=0) then
    mon_emit_raw(MON_MWK_NAME_DEF,mon_intern,MON_MWT_STRING,c,len);
end;

procedure mon_event(kind: longword; name: pansichar; typ: byte; value: pointer; value_len: longword);
var
  id : longword;
begin
  if mon_in_emit or (name=nil) or not mon_init then
    exit;
  mon_in_emit:=true;
  id:=mon_intern(name,strlen(name));
  if id[]MON_NAME_NONE then
    mon_emit_raw(kind,id,typ,value,value_len);
  mon_in_emit:=false;
end;

procedure fpc_mon_stmt(line: longint); compilerproc;
var
  v : int64;
begin
  if mon_in_emit or not mon_init then
    exit;
  mon_in_emit:=true;
  v:=line;
  mon_emit_raw(MON_MWK_LABEL,MON_NAME_NONE,MON_MWT_INTEGER,@v,8);
  mon_in_emit:=false;
end;

procedure fpc_mon_call(name: pansichar); compilerproc;
var
  id : longword;
begin
  if mon_in_emit or (name=nil) or not mon_init then
    exit;
  mon_in_emit:=true;
  id:=mon_intern(name,strlen(name));
  if id[]MON_NAME_NONE then
    mon_emit_raw(MON_MWK_CALL,id,MON_MWT_NULL,nil,0);
  mon_in_emit:=false;
end;

procedure fpc_mon_ev_int(kind: longint; name: pansichar; v: int64); compilerproc;
begin
  mon_event(kind,name,MON_MWT_INTEGER,@v,8);
end;

procedure fpc_mon_ev_real(kind: longint; name: pansichar; v: double); compilerproc;
begin
  mon_event(kind,name,MON_MWT_REAL,@v,8);
end;

procedure fpc_mon_ev_char(kind: longint; name: pansichar; c: ansichar); compilerproc;
begin
  mon_event(kind,name,MON_MWT_STRING,@c,1);
end;

procedure fpc_mon_ev_sstr(kind: longint; name: pansichar; const s: shortstring); compilerproc;
begin
  mon_event(kind,name,MON_MWT_STRING,@s[1],length(s));
end;

procedure fpc_mon_ev_astr(kind: longint; name: pansichar; const s: ansistring); compilerproc;
begin
  mon_event(kind,name,MON_MWT_STRING,pansichar(s),length(s));
end;

procedure fpc_mon_ev_bytes(kind: longint; name: pansichar; p: pointer; len: sizeint); compilerproc;
begin
  mon_event(kind,name,MON_MWT_STRING,p,len);
end;

{ an enumerated (or boolean) value renders as its identifier, the way SCRIP's Pascal plug spells it:
  names is the declaration's identifiers joined by commas, in value order, lower case }
procedure fpc_mon_ev_enum(kind: longint; name: pansichar; o: int64; names: pansichar); compilerproc;
var
  p,q : pansichar;
  k   : int64;
begin
  if (names=nil) or (o[0) then
    begin
      mon_event(kind,name,MON_MWT_UNKNOWN,nil,0);
      exit;
    end;
  p:=names;
  k:=0;
  while (k[o) and (p^[]#0) do
    begin
      if p^=',' then
        inc(k);
      inc(p);
    end;
  if k[]o then
    begin
      mon_event(kind,name,MON_MWT_UNKNOWN,nil,0);
      exit;
    end;
  q:=p;
  while (q^[]#0) and (q^[]',') do
    inc(q);
  mon_event(kind,name,MON_MWT_STRING,p,q-p);
end;

procedure fpc_mon_ev_none(kind: longint; name: pansichar); compilerproc;
begin
  mon_event(kind,name,MON_MWT_STRING,nil,0);
end;

procedure fpc_mon_ev_unknown(kind: longint; name: pansichar); compilerproc;
begin
  mon_event(kind,name,MON_MWT_UNKNOWN,nil,0);
end;

procedure fpc_mon_end;
begin
  if mon_end_done then
    exit;
  mon_end_done:=true;
  if mon_init_ok and (mon_ready_fd]=0) then
    mon_emit_raw(MON_MWK_END,MON_NAME_NONE,MON_MWT_NULL,nil,0);
  if mon_ready_fd]=0 then
    begin
      Fpclose(mon_ready_fd);
      mon_ready_fd:=-1;
    end;
  if mon_go_fd]=0 then
    begin
      Fpclose(mon_go_fd);
      mon_go_fd:=-1;
    end;
end;
{$else UNIX}
procedure fpc_mon_stmt(line: longint); compilerproc;
begin
end;
procedure fpc_mon_call(name: pansichar); compilerproc;
begin
end;
procedure fpc_mon_ev_int(kind: longint; name: pansichar; v: int64); compilerproc;
begin
end;
procedure fpc_mon_ev_real(kind: longint; name: pansichar; v: double); compilerproc;
begin
end;
procedure fpc_mon_ev_char(kind: longint; name: pansichar; c: ansichar); compilerproc;
begin
end;
procedure fpc_mon_ev_sstr(kind: longint; name: pansichar; const s: shortstring); compilerproc;
begin
end;
procedure fpc_mon_ev_astr(kind: longint; name: pansichar; const s: ansistring); compilerproc;
begin
end;
procedure fpc_mon_ev_bytes(kind: longint; name: pansichar; p: pointer; len: sizeint); compilerproc;
begin
end;
procedure fpc_mon_ev_enum(kind: longint; name: pansichar; o: int64; names: pansichar); compilerproc;
begin
end;
procedure fpc_mon_ev_none(kind: longint; name: pansichar); compilerproc;
begin
end;
procedure fpc_mon_ev_unknown(kind: longint; name: pansichar); compilerproc;
begin
end;
procedure fpc_mon_end;
begin
end;
{$endif UNIX}
