# lib/HappyNumbers.rakumod

unit module HappyNumbers;

class HappySequence does Iterator does Iterable {
    has Int $.base is rw = 10;
    has Int $.power is rw = 2;

    has Int $!next-number = 1;
    has %!cache;

    submethod TWEAK() {
        %!cache{1} = True;
    }

    method iterator() { self }

    method pull-one() {
        loop {
            my $n = $!next-number;
            my $normalized = $n.base($!base).comb.grep(* !~~ 0).sort.join.parse-base($!base);
            if self!is-happy($normalized) {
                $!next-number++;
                return $n;
            }
            $!next-number++;
        }
    }

    method is-lazy() { True }

    method !is-happy($normalized) {
        return %!cache{$normalized} if %!cache{$normalized}:exists;

        my %seen;
        my $current = $normalized;
        my @path;

        loop {
            if %!cache{$current}:exists {
                my $happy = %!cache{$current};
                for @path -> $num {
                    %!cache{$num} = $happy;
                }
                return $happy;
            }

            if %seen{$current}:exists {
                for @path -> $num {
                    %!cache{$num} = False;
                }
                return False;
            }

            %seen{$current} = True;
            @path.push($current);

            my $next = $current.base($!base).comb.map(*.parse-base($!base) ** $!power).sum;
            $next = $next.base($!base).comb.grep(* !~~ 0).sort.join.parse-base($!base);

            $current = $next;
        }
    }
}

class PureHappySequence does Iterator does Iterable {
    has Int $.base is rw = 10;
    has Int $.power is rw = 2;

    has HappySequence $!sequence;
    has %!seen;

    submethod TWEAK() {
        $!sequence = HappyNumbers::HappySequence.new(:$!base, :$!power);
    }

    method iterator() { self }

    method pull-one() {
        loop {
            my $n = $!sequence.pull-one();
            my $sig = $n.base($!base).comb.grep(* !~~ 0).sort.join;
            unless %!seen{$sig}:exists {
                %!seen{$sig} = True;
                return $n;
            }
        }
    }

    method is-lazy() { True }
}

class Calculator {
    has Int $.base is rw = 10;
    has Int $.power is rw = 2;
    has Bool $.get-pure is rw = False;
    has Bool $.verbose is rw = False;

    has @!happy-numbers;
    has %!happiness;
    has @!pure-numbers;
    has Int $!max-tried;
    has @!sequences;

    submethod TWEAK() {
        %!happiness{1} = %(next => 1, iter => 0, zhappy => True);
    }

    method calculate(:$limit) {
        @!happy-numbers = (1,);
        @!pure-numbers = ();
        @!sequences = ();
        %!happiness = %(1 => %(next => 1, iter => 0, zhappy => True));

        my $normalize-num = *.base($!base).comb.grep(* !~~ 0).sort.join.parse-base($!base);

        for 2 .. * -> $number {
            my $normalized = $normalize-num($number);
            my $is-happy = self!happy($normalized, '', :$normalize-num);
            if $is-happy<zhappy> {
                @!happy-numbers.push($number);
                @!sequences.push($number => $is-happy<seq> // ($number.Str));
            }
            last if @!happy-numbers.unique(:as($!get-pure ?? $normalize-num !! *)).elems == $limit;
            LAST {
                $!max-tried = $number;
            }
        }

        @!pure-numbers = @!happy-numbers.unique(:as($normalize-num));

        return %(
            :happy-numbers(@!happy-numbers),
            :pure-numbers(@!pure-numbers),
            :max-tried($!max-tried),
            :happiness(%!happiness),
            :hash-size(%!happiness.elems),
            :sequences(@!sequences),
        );
    }

    method !happy($n, $seq = "", :$normalize-num) {
        my sub is-happy {
            my $next = $normalize-num($n.base($!base).comb.map(*.parse-base($!base) ** $!power).sum);
            %!happiness{$n} = %(iter => 1);
            return %!happiness{$n} = %(|%($_), :$next, iter => $_<iter> + 1, :seq(($seq.Bool ?? $seq !! $n.Str) ~ " => $next"))
                with self!happy($next, ($seq.Bool ?? $seq !! $n.Str) ~ " => $next", :$normalize-num);
        }
        return $n == 1 ?? %(|%!happiness<1>, iter => 1, :seq($seq || "1")) !! %!happiness{$n} || is-happy()
    }

    method happy-sequence() {
        HappySequence.new(:$.base, :$.power)
    }

    method pure-sequence() {
        PureHappySequence.new(:$.base, :$.power)
    }

    method happiness() { %!happiness }
    method happy-numbers() { @!happy-numbers }
    method pure-numbers() { @!pure-numbers }
    method sequences() { @!sequences }
}
