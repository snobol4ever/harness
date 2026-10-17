my int $s = -1;
while ++$s <= 9 {
    my int $e = -1;
    while ++$e <= 9 {
        next if $e == $s;
        my int $n = -1;
        while ++$n <= 9 {
            next if $n == $s;
            next if $n == $e;
            my int $d = -1;
            while ++$d <= 9 {
                next if $d == $s;
                next if $d == $e;
                next if $d == $n;
                my int $m = -1;
                while ++$m <= 9 {
                    next if $m == $s;
                    next if $m == $e;
                    next if $m == $n;
                    next if $m == $d;
                    my int $o = -1;
                    while ++$o <= 9 {
                        next if $o == $s;
                        next if $o == $e;
                        next if $o == $n;
                        next if $o == $d;
                        next if $o == $m;
                        my int $r = -1;
                        while ++$r <= 9 {
                            next if $r == $s;
                            next if $r == $e;
                            next if $r == $n;
                            next if $r == $d;
                            next if $r == $m;
                            next if $r == $o;
                            my int $y = -1;
                            while ++$y <= 9 {
                                next if $y == $s;
                                next if $y == $e;
                                next if $y == $n;
                                next if $y == $d;
                                next if $y == $m;
                                next if $y == $o;
                                next if $y == $r;
                                say 1;
                            }
                        }
                    }
                }
            }
        }
    }
}
