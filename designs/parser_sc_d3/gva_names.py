import subprocess, sys, struct, re
def names(so, lang):
    S = subprocess.run(["readelf","-WS",so],capture_output=True,text=True,encoding="latin1").stdout
    secs=[]
    for m in re.finditer(r"\]\s+(\S+)\s+\S+\s+([0-9a-f]{16})\s+([0-9a-f]+)\s+([0-9a-f]+)", S):
        secs.append((m.group(1), int(m.group(2),16), int(m.group(3),16), int(m.group(4),16)))
    def off(a):
        for n,ad,of,sz in secs:
            if ad and ad<=a<ad+sz and n not in (".bss",): return of+(a-ad)
        return None
    sym = subprocess.run(["readelf","-Ws","--dyn-syms",so],capture_output=True,text=True,encoding="latin1").stdout
    da=None
    for l in sym.splitlines():
        if l.rstrip().endswith(" parser_%s_sc_module"%lang):
            da=int(l.split()[1],16); break
    R = subprocess.run(["readelf","-Wr",so],capture_output=True,text=True,encoding="latin1").stdout
    rel={}
    for l in R.splitlines():
        p=l.split()
        if len(p)>=4 and p[2]=="R_X86_64_RELATIVE": rel[int(p[0],16)]=int(p[3],16)
    data=open(so,"rb").read()
    n_gva=struct.unpack_from("<q",data,off(da+24))[0]
    tab=rel[da+16]
    out=[]
    for k in range(n_gva):
        a=rel.get(tab+8*k)
        if a is None: out.append(None); continue
        o=off(a); e=data.index(b"\0",o); out.append(data[o:e].decode("latin1"))
    return out
if __name__=="__main__":
    d=sys.argv[1]; res={}
    for lang in sys.argv[2:]:
        res[lang]=names("%s/libscrip_parser_%s.so"%(d,lang),lang)
        ns=[x for x in res[lang] if x]
        import collections
        c=collections.Counter(re.match(r"[A-Za-z]*_|[^A-Za-z]|[A-Za-z]+",x).group(0) if re.match(r"[a-z]{2,3}_",x) else "(bare)" for x in ns)
        print(lang,"n_gva",len(res[lang]),"named",len(ns),"first_named",next((i for i,x in enumerate(res[lang]) if x),None),dict(c.most_common(8)))
    ls=list(res)
    for i in range(len(ls)):
        for j in range(i+1,len(ls)):
            a=set(x for x in res[ls[i]] if x); b=set(x for x in res[ls[j]] if x)
            inter=a&b
            c=collections.Counter(x.split("_")[0]+"_" if re.match(r"[a-z]{2,3}_",x) else "(bare)" for x in inter)
            print("SHARED",ls[i],ls[j],len(inter),dict(c), sorted(x for x in inter if not re.match(r"[a-z]{2,3}_",x))[:12])
