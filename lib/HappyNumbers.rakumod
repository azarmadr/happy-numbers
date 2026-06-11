# lib/HappyNumbers.rakumod

unit module HappyNumbers;

our sub normalize ($n, :$base = 10) {
    $n.base($base).comb.grep(* !~~0).sort.join.parse-base($base)
}
our sub is-normalized ($n, :$base) {
    $n.&normalize:$base eq $n
}
sub next-happy-seq ($n, :$base, :$power) {
    $n.base($base).comb.map(*.parse-base($base) ** $power).sum
}
class HappySeq does Iterator {
    has Int $.base = 10;
    has Int $.power = 2;
    has $!current = 1;
    has %!graph = %(1 => %(:1next, :1happy));

    method !is-happy ($n) {
        return %!graph{$n}<happy> if %!graph{$n}<happy>:exists;
        return %!graph{$n}<happy> = 0 if $n != 1 && %!graph{$n};

        my $next = $n.&next-happy-seq(:$!base:$!power).&normalize :$!base;
        %!graph{$n} = %(:$next);
        my $happy;
        $happy = 1 if $next == 1;
        $happy = %!graph{$next}<happy> || self!is-happy($next);
        $happy .= Int;
        %!graph{$n}<happy> = $happy;
    }
    method graph {%!graph}
    method pull-one (:$pure = False) {
        loop {
            my $c = $!current++;
            next unless !$pure or $c.&is-normalized :$!base;
            return $c if self!is-happy($c.&normalize :$!base) || $!current >99
        }
    }
    method is-lazy {True}
}
