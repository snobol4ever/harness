import sys, itertools
op=sys.argv[1]; name=sys.argv[2]
POOL=["''","'abc'","'  x  '","'12'","'-5'","'3.7'","'a,b'","0","1","2","-1","7","100","1.5","-2.5","0.0",".V","'  '","'+4'","'1e2'"]
out=["        &ERRLIMIT = 1000000","        V = 'vv'"]
combos=list(itertools.product(POOL,POOL))
for i,c in enumerate(combos):
    out.append("        &ERRTYPE = 0")
    out.append("        A1 = %s"%c[0]); out.append("        A2 = %s"%c[1])
    out.append("        X = A1 %s A2   :F(F%d)"%(op,i))
    lab=','.join(c)
    out.append('        OUTPUT = "%d (%s) ok " DATATYPE(X) " [" X "] " &ERRTYPE   :(N%d)'%(i,lab,i))
    out.append('F%d     OUTPUT = "%d (%s) fail " &ERRTYPE'%(i,i,lab))
    out.append("N%d"%i)
out.append("END")
open(name+'.sno','w').write('\n'.join(out)+'\n')
