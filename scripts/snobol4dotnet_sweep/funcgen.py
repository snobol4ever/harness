#!/usr/bin/env python3
# gen.py FUNC NARGS [SEED]: write FUNC.sno that calls FUNC with argument tuples drawn from a pool, through variables (so nothing is pre-evaluated),
# printing for each case: ok datatype value errtype | fail errtype
import sys, random, itertools
func=sys.argv[1]; n=int(sys.argv[2]); seed=int(sys.argv[3]) if len(sys.argv)>3 else 1
POOL=["''","'abc'","'  x  '","'12'","'-5'","'3.7'","'a,b'","'ABCabc'","0","1","2","-1","7","100","1.5","-2.5","0.0","'+4'","'1e2'",".V","'  '"]
rnd=random.Random(seed)
if n==0: combos=[()]
elif n==1: combos=[(a,) for a in POOL]
elif n==2: combos=list(itertools.product(POOL,POOL))
else:
    combos=list(itertools.product(POOL,repeat=n)); rnd.shuffle(combos); combos=combos[:350]
out=["        &ERRLIMIT = 1000000","        &TRIM = 0","        V = 'vv'","        T = TABLE()","        A = ARRAY(3)","        P = LEN(2)"]
for i,c in enumerate(combos):
    out.append("        &ERRTYPE = 0")
    for j,a in enumerate(c): out.append("        A%d = %s"%(j+1,a))
    call="%s(%s)"%(func,','.join("A%d"%(j+1) for j in range(len(c)))) if c else "%s()"%func
    out.append("        X = %s   :F(F%d)"%(call,i))
    lab=','.join(c)
    out.append('        OUTPUT = "%d (%s) ok " DATATYPE(X) " [" X "] " &ERRTYPE   :(N%d)'%(i,lab,i))
    out.append('F%d     OUTPUT = "%d (%s) fail " &ERRTYPE'%(i,i,lab))
    out.append("N%d"%i)
out.append("END")
open(func+'.sno','w').write('\n'.join(out)+'\n')
