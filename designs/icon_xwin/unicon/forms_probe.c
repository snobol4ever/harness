#include "h/rt.h"
#include <stdio.h>
#include <stddef.h>
#define P(k, v) printf("%s\t%lld\n", k, (long long)(v))
#define X(k, v) printf("%s\t%#llx\n", k, (unsigned long long)(v))
int main(void) {
    P("sizeof word", sizeof(word)); P("sizeof struct descrip", sizeof(struct descrip)); P("descrip.vword offset", offsetof(struct descrip, vword));
    X("F_Nqual", F_Nqual); X("F_Var", F_Var); X("F_Ptr", F_Ptr); X("F_Typecode", F_Typecode); X("TypeMask", TypeMask); X("OffsetMask", OffsetMask);
    P("T_Null", T_Null); P("T_Integer", T_Integer); P("T_Lrgint", T_Lrgint); P("T_Real", T_Real); P("T_Cset", T_Cset); P("T_File", T_File); P("T_Proc", T_Proc);
    P("T_Record", T_Record); P("T_List", T_List); P("T_Lelem", T_Lelem); P("T_Set", T_Set); P("T_Table", T_Table); P("T_Coexpr", T_Coexpr); P("T_External", T_External);
    X("D_Null", D_Null); X("D_Integer", D_Integer); X("D_Lrgint", D_Lrgint); X("D_Real", D_Real); X("D_Cset", D_Cset); X("D_File", D_File); X("D_Record", D_Record); X("D_List", D_List);
#ifdef DescriptorDouble
    P("DescriptorDouble", 1); P("descrip.vword.realval offset", offsetof(struct descrip, vword.realval));
#else
    P("DescriptorDouble", 0); P("sizeof struct b_real", sizeof(struct b_real)); P("b_real.realval offset", offsetof(struct b_real, realval));
#endif
    P("sizeof struct b_file", sizeof(struct b_file)); P("b_file.fd offset", offsetof(struct b_file, fd)); P("b_file.status offset", offsetof(struct b_file, status)); P("b_file.fname offset", offsetof(struct b_file, fname));
    P("Fs_Read", Fs_Read); P("Fs_Write", Fs_Write); P("Fs_Window", Fs_Window);
    P("sizeof struct b_cset", sizeof(struct b_cset)); P("b_cset.size offset", offsetof(struct b_cset, size)); P("b_cset.bits offset", offsetof(struct b_cset, bits)); P("CsetSize", CsetSize); P("sizeof cset word", sizeof(((struct b_cset *)0)->bits[0]));
    P("sizeof struct b_bignum", sizeof(struct b_bignum)); P("b_bignum.blksize offset", offsetof(struct b_bignum, blksize)); P("b_bignum.msd offset", offsetof(struct b_bignum, msd)); P("b_bignum.lsd offset", offsetof(struct b_bignum, lsd)); P("b_bignum.sign offset", offsetof(struct b_bignum, sign)); P("b_bignum.digits offset", offsetof(struct b_bignum, digits)); P("sizeof DIGIT", sizeof(DIGIT));
    P("sizeof struct b_list", sizeof(struct b_list)); P("b_list.size offset", offsetof(struct b_list, size)); P("b_list.listhead offset", offsetof(struct b_list, listhead)); P("b_list.listtail offset", offsetof(struct b_list, listtail));
    P("A_Resume", A_Resume); P("A_Continue", A_Continue); P("Succeeded", Succeeded); P("Failed", Failed); P("CvtFail", CvtFail); P("NoCvt", NoCvt); P("G_Csusp", G_Csusp);
#ifdef RunError
    P("the error signal (RunError)", RunError);
#else
    P("the error signal (Error)", Error);
#endif
    P("XKey_Window", XKey_Window); P("XKey_Fg", XKey_Fg);
    P("sizeof struct tend_desc", sizeof(struct tend_desc)); P("tend_desc.previous offset", offsetof(struct tend_desc, previous)); P("tend_desc.num offset", offsetof(struct tend_desc, num)); P("tend_desc.d offset", offsetof(struct tend_desc, d));
    return 0;
}
