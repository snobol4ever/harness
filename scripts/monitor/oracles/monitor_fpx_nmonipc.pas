{
    nmonipc.pas -- the IPC sync-step monitor's fire-point injection (the SCRIP fpc-mon fork of Free Pascal).

    Under -gi (cs_monitor_ipc) the parser and the procedure code generator call these builders to inject calls to the
    RTL's fpc_mon_* compilerprocs (rtl/inc/monipch.inc): a statement event at the start of every element of every
    statement list (pstatmnt.pas statement_block / repeat_statement), a value event after every store to a named
    variable and at the top of every for-loop iteration for its control variable (pstatmnt.pas statement / for_statement),
    a call event at every user procedure's entry and a return event at its exit label (psub.pas add_entry_exit_code).
    The events are the contract of MONITOR-BINARY-DESIGN.md section THE ORACLES ARE INSTRUMENTED IN THEIR OWN SOURCE:
    STMT carries the statement's own source line; VALUE carries the variable's name as SCRIP spells it (lower case,
    <lval> for a structure element) and the stored value typed integer / real / string, an enumerated or boolean value
    as its identifier, else the UNKNOWN wildcard; CALL the procedure's name; RETURN the name and the function's result
    (the empty string for a procedure).
}
unit nmonipc;

{$i fpcdefs.inc}

interface

    uses
      node,symdef;

    const
      MON_KIND_VALUE  = 1;
      MON_KIND_RETURN = 3;

    function mon_ipc_on: boolean;
    function mon_ipc_proc_wanted(pd: tprocdef): boolean;
    function mon_ipc_stmt_node(line: longint): tnode;
    function mon_ipc_call_node(pd: tprocdef): tnode;
    function mon_ipc_param_nodes(pd: tprocdef): tnode;
    function mon_ipc_return_node(pd: tprocdef): tnode;
    function mon_ipc_store_name(lhs: tnode; out name: string): boolean;
    function mon_ipc_value_node(kind: longint; const name: string; valnode: tnode): tnode;

implementation

    uses
      globtype,globals,cutils,cclasses,constexp,
      symconst,symbase,symtype,symsym,symtable,defutil,
      ncal,ncon,ncnv,nld,nmem,nbas,nutils,pass_1;


    function mon_ipc_on: boolean;
      begin
        result:=cs_monitor_ipc in current_settings.globalswitches;
      end;


    function mon_ipc_proc_wanted(pd: tprocdef): boolean;
      begin
        result:=mon_ipc_on and assigned(pd) and assigned(pd.procsym) and
          (pd.proctypeoption in [potype_none,potype_procedure,potype_function]) and
          (pd.procoptions*[po_assembler,po_compilerproc,po_internconst,po_external]=[]) and
          assigned(pd.owner) and (pd.owner.symtabletype in [staticsymtable,localsymtable]);
      end;


    function mon_pchar_node(const s: string): tnode;
      var
        p : pansichar;
      begin
        getmem(p,length(s)+1);
        if length(s)>0 then
          move(s[1],p^,length(s));
        p[length(s)]:=#0;
        result:=cstringconstnode.createpchar(p,length(s),nil);
      end;


    { the parameter chain is built last parameter first }
    function mon_params2(kind: longint; const name: string; extra: tnode): tnode;
      begin
        result:=ccallparanode.create(mon_pchar_node(name),ccallparanode.create(genintconstnode(kind),nil));
        if assigned(extra) then
          result:=ccallparanode.create(extra,result);
      end;


    function mon_ipc_stmt_node(line: longint): tnode;
      begin
        result:=ccallnode.createintern('fpc_mon_stmt',ccallparanode.create(genintconstnode(line),nil));
      end;


    function mon_proc_name(pd: tprocdef): string;
      begin
        result:=lower(pd.procsym.realname);
      end;


    function mon_ipc_call_node(pd: tprocdef): tnode;
      begin
        result:=ccallnode.createintern('fpc_mon_call',ccallparanode.create(mon_pchar_node(mon_proc_name(pd)),nil));
      end;


    { THE BIND EVENTS (coo 2026-09-23, row monitor-a-value-event-fires-per-parameter-at-call-argument-bind-time-...): one VALUE
      per visible parameter, in declaration order, right after the call event -- which value landed in which parameter slot.
      Without it an argument-evaluation-order bug read AGREE: both engines call the producing function the same number of
      times with the same results, and only the BINDING differs (hq_pascal, tbs_tb0207, SCRIP a3dd15832). Hidden parameters
      (self, result, high(), the parent frame) are not the program's; an untyped (formal) parameter cannot be loaded as a
      value, so it reports UNKNOWN without a load. }
    function mon_ipc_param_nodes(pd: tprocdef): tnode;
      var
        i       : longint;
        para    : tparavarsym;
        newstat : tstatementnode;
      begin
        result:=internalstatements(newstat);
        for i:=0 to pd.paras.count-1 do
          begin
            para:=tparavarsym(pd.paras[i]);
            if vo_is_hidden_para in para.varoptions then
              continue;
            if para.vardef.typ=formaldef then
              addstatement(newstat,ccallnode.createintern('fpc_mon_ev_unknown',mon_params2(MON_KIND_VALUE,lower(para.realname),nil)))
            else
              addstatement(newstat,mon_ipc_value_node(MON_KIND_VALUE,lower(para.realname),cloadnode.create(para,para.owner)));
          end;
      end;


    function mon_ipc_return_node(pd: tprocdef): tnode;
      begin
        if is_void(pd.returndef) or not assigned(pd.funcretsym) then
          result:=ccallnode.createintern('fpc_mon_ev_none',mon_params2(MON_KIND_RETURN,mon_proc_name(pd),nil))
        else
          result:=mon_ipc_value_node(MON_KIND_RETURN,mon_proc_name(pd),cloadnode.create(pd.funcretsym,pd.funcretsym.owner));
      end;


    function mon_ipc_store_name(lhs: tnode; out name: string): boolean;
      var
        n   : tnode;
        sym : tsym;
      begin
        result:=false;
        name:='';
        n:=lhs;
        while assigned(n) and (n.nodetype=typeconvn) do
          n:=ttypeconvnode(n).left;
        if not assigned(n) then
          exit;
        case n.nodetype of
          loadn:
            begin
              sym:=tloadnode(n).symtableentry;
              case sym.typ of
                staticvarsym,
                localvarsym,
                paravarsym:
                  begin
                    { the function result variable ($result) reports under the function's name }
                    if (vo_is_funcret in tabstractvarsym(sym).varoptions) and assigned(sym.owner) and
                       assigned(sym.owner.defowner) and (sym.owner.defowner.typ=procdef) then
                      name:=mon_proc_name(tprocdef(sym.owner.defowner))
                    else
                      name:=lower(sym.realname);
                    result:=name<>'';
                  end;
                absolutevarsym:
                  begin
                    name:=lower(sym.realname);
                    result:=name<>'';
                  end;
              end;
            end;
          vecn,
          subscriptn,
          derefn:
            begin
              name:='<lval>';
              result:=true;
            end;
        end;
      end;


    function mon_enum_names(def: tdef): string;
      var
        i : longint;
        s : tenumsym;
      begin
        result:='';
        while (def.typ=enumdef) and assigned(tenumdef(def).basedef) do
          def:=tenumdef(def).basedef;
        if def.typ<>enumdef then
          exit;
        for i:=0 to tenumdef(def).symtable.SymList.Count-1 do
          begin
            s:=tenumsym(tenumdef(def).symtable.SymList[i]);
            if i>0 then
              result:=result+',';
            result:=result+lower(s.realname);
          end;
      end;


    function mon_ipc_value_node(kind: longint; const name: string; valnode: tnode): tnode;
      var
        def : tdef;
      begin
        if not assigned(valnode.resultdef) then
          typecheckpass(valnode);
        def:=valnode.resultdef;
        if is_boolean(def) then
          result:=ccallnode.createintern('fpc_mon_ev_enum',
            ccallparanode.create(mon_pchar_node('false,true'),
              mon_params2(kind,name,ctypeconvnode.create_internal(valnode,s64inttype))))
        else if def.typ=enumdef then
          result:=ccallnode.createintern('fpc_mon_ev_enum',
            ccallparanode.create(mon_pchar_node(mon_enum_names(def)),
              mon_params2(kind,name,ctypeconvnode.create_internal(valnode,s64inttype))))
        else if is_char(def) then
          result:=ccallnode.createintern('fpc_mon_ev_char',mon_params2(kind,name,valnode))
        else if is_integer(def) or is_ordinal(def) then
          result:=ccallnode.createintern('fpc_mon_ev_int',mon_params2(kind,name,ctypeconvnode.create_internal(valnode,s64inttype)))
        else if is_real(def) then
          result:=ccallnode.createintern('fpc_mon_ev_real',mon_params2(kind,name,ctypeconvnode.create_internal(valnode,s64floattype)))
        else if is_shortstring(def) then
          result:=ccallnode.createintern('fpc_mon_ev_sstr',mon_params2(kind,name,valnode))
        else if is_ansistring(def) then
          result:=ccallnode.createintern('fpc_mon_ev_astr',mon_params2(kind,name,valnode))
        else if is_chararray(def) then
          result:=ccallnode.createintern('fpc_mon_ev_bytes',
            ccallparanode.create(genintconstnode(int64(tarraydef(def).elecount)),
              mon_params2(kind,name,caddrnode.create_internal(valnode))))
        else
          begin
            valnode.free;
            result:=ccallnode.createintern('fpc_mon_ev_unknown',mon_params2(kind,name,nil));
          end;
      end;

end.
