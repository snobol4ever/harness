grammar G { rule TOP { "a" } }
say G.parse("a");
grammar H { rule TOP { "ab" } }
say H.parse("ab");
say G.parse("zz");
