class A { method m($n) { "a$n" } }
class B is A { method m($n) { $n > 0 ?? self.m($n - 1) !! nextsame() } }
say B.new.m(70);
say B.new.m(3);
