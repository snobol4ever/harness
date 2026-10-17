class Point {
    has num $.x;
    has num $.y;
    submethod BUILD(num :$x, num :$y) { $!x = $x; $!y = $y; }
    method add(Point $b) { return self.bless(:x($!x + $b.x), :y($!y + $b.y)); }
}
my int $i = 0;
my Point $a = Point.new(:x(1.5e0), :y(2.5e0));
my Point $b = Point.new(:x(3.25e0), :y(4.75e0));
while $i < 20000 { $a = $a.add($b).add($b); $i = $i + 1; }
print $a.x, ' ', $a.y;
print "\n";
