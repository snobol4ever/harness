#!/usr/bin/env python3
# ctxgen.py: the tables of the type-by-context sweep -- VALUES, a pool of values of every datatype, and CTX, the statements (operator
# operands, function arguments, pattern positions, subscripts, keyword assignments) each value is put into as V -- and program(i, names),
# the program that applies context i to those values and prints "i.VALUE ok|fail ERRTYPE" for each
import sys
VALUES = {
 'STR':"'abc'", 'NUM':"'12'", 'NULL':"''", 'INT':"7", 'REAL':"2.5", 'NEG':"-3",
 'DATA':"D(1,2,3)", 'ARR':"ARRAY(3)", 'TAB':"TABLE()", 'PAT':"LEN(2)", 'EXPR':"*S", 'NAME':".S", 'CODE':"CODE('X = 1')",
}
CTX = [
 "L = {v} 'x'", "L = 'x' {v}", "L = SIZE({v})", "L = REVERSE({v})", "L = TRIM({v})", "L = DUPL({v}, 2)", "L = DUPL('a', {v})",
 "L = {v} + 1", "L = 1 + {v}", "L = {v} * 2", "L = {v} / 2", "L = {v} ** 2", "L = -{v}", "L = +{v}",
 "L = LGT({v}, 'a')", "L = LGT('a', {v})", "L = IDENT({v}, {v})", "L = DIFFER({v}, 'a')", "L = IDENT({v})", "L = DIFFER({v})",
 "L = EQ({v}, 1)", "L = LT(1, {v})", "L = REMDR({v}, 2)",
 "'abc' ? {v}", "{v} ? 'a'", "{v} ? LEN(1)", "L = 'abc' ? {v}", "'abc' ? 'b' . {v}", "'abc' ? LEN(1) $ {v}",
 "L = LEN({v})", "L = POS({v})", "L = TAB({v})", "L = SPAN({v})", "L = BREAK({v})", "L = ANY({v})", "L = ARBNO({v})", "L = FENCE({v})",
 "L = CONVERT({v}, 'STRING')", "L = CONVERT({v}, 'INTEGER')", "L = CONVERT({v}, 'REAL')", "L = CONVERT({v}, 'PATTERN')", "L = CONVERT({v}, 'NAME')", "L = CONVERT({v}, 'EXPRESSION')", "L = CONVERT({v}, 'ARRAY')", "L = CONVERT({v}, 'TABLE')", "L = CONVERT({v}, 'CODE')",
 "L = COPY({v})", "L = DATATYPE({v})", "L = INTEGER({v})", "L = REAL({v})", "L = EVAL({v})", "L = CODE({v})", "L = CHAR({v})", "L = CHOP({v})", "L = SQRT({v})", "L = REPLACE({v}, 'a', 'b')", "L = SUBSTR({v}, 1, 1)", "L = SUBSTR('abc', {v}, 1)",
 "L = LPAD({v}, 5)", "L = RPAD('a', {v})", "L = SORT({v})", "L = RSORT({v})", "L = PROTOTYPE({v})", "L = ITEM({v}, 1)", "L = ITEM('x', {v})", "L = APPLY({v})", "L = ARG({v}, 1)",
 "L = ${v}", "L = .{v}", "L = {v}<1>", "A3<{v}> = 1", "T3<{v}> = 1", "L = A3<{v}>", "L = T3<{v}>",
 "OUTPUT = {v}", "L = *{v}", "L = ~{v}", "L = ?{v}", "L = @{v}",
 "L = {v} | 'a'", "L = 'a' | {v}", "L = {v} {v}",  "&TRIM = {v}", "&ANCHOR = {v}", "&MAXLNGTH = {v}",
 "L = DEFINE({v})", "L = OPSYN({v}, 'SIZE')", "L = LOCAL({v}, 1)", "L = FIELD({v}, 1)", "L = TABLE({v})", "L = ARRAY({v})", "L = DATA({v})", "L = CLEAR({v})", "L = STOPTR({v}, 'VALUE')", "L = TRACE({v}, 'VALUE')",
]

# the program header: &ERRLIMIT lets a run go past an error, DATA type D, the string S, an array A3 and a table T3
HEAD = ["        &ERRLIMIT = 1000000", "        &TRIM = 0", "        DATA('D(X,Y,Z)')", "        S = 'vv'", "        A3 = ARRAY(3)", "        T3 = TABLE()"]


def program(i, names):
    """The program that puts context CTX[i] around each of the values `names`, one statement each."""
    out = list(HEAD)
    for k, vn in enumerate(names):
        out += ["        &ERRTYPE = 0", "        V = %s" % VALUES[vn], "        L = ''",
                "        %s   :S(S%d)F(F%d)" % (CTX[i].format(v="V"), k, k),
                "S%d     OUTPUT = '%d.%s ok ' &ERRTYPE   :(N%d)" % (k, i, vn, k),
                "F%d     OUTPUT = '%d.%s fail ' &ERRTYPE" % (k, i, vn), "N%d" % k]
    out.append("END")
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    # python3 ctxgen.py : list the contexts with their numbers
    for i, c in enumerate(CTX):
        print(i, c)
