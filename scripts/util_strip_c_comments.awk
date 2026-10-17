BEGIN { inb = 0; Q = sprintf("%c", 39); BS = sprintf("%c", 92); DQ = sprintf("%c", 34) }
{
    line = $0; out = ""; i = 1; n = length(line); ins = 0; inc = 0;
    while (i <= n) {
        c = substr(line, i, 1); d = substr(line, i, 2);
        if (inb)  { if (d == "*/") { inb = 0; out = out "  "; i += 2 } else { out = out " "; i++ } continue }
        if (ins)  { out = out c; if (c == BS) { out = out substr(line, i + 1, 1); i += 2; continue } if (c == DQ) ins = 0; i++; continue }
        if (inc)  { out = out c; if (c == BS) { out = out substr(line, i + 1, 1); i += 2; continue } if (c == Q)  inc = 0; i++; continue }
        if (d == "/*") { inb = 1; out = out "  "; i += 2; continue }
        if (d == "//") { break }
        if (c == DQ)   { ins = 1; out = out c; i++; continue }
        if (c == Q)    { inc = 1; out = out c; i++; continue }
        out = out c; i++;
    }
    print out
}
