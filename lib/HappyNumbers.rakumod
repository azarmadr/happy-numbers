# lib/HappyNumbers.rakumod

unit module HappyNumbers;

class HappyEngine {
    has Int $.base is rw = 10;
    has Int $.power is rw = 2;
    has %!happiness;

    submethod TWEAK() {
        %!happiness{1} = %(next => 1, iter => 0, zhappy => True, seq => "1");
    }

    method normalize($n) {
        $n.base($!base).comb.grep(* !~~ 0).sort.join.parse-base($!base);
    }

    method !step($n) {
        self.normalize($n.base($!base).comb.map(*.parse-base($!base) ** $!power).sum);
    }

    method !happy($n, $seq = "") {
        my sub is-happy {
            my $next = self!step($n);
            %!happiness{$n} = %(iter => 1);
            return %!happiness{$n} = %(
                |%($_),
                :$next,
                iter => $_<iter> + 1,
                :seq(($seq.Bool ?? $seq !! $n.Str) ~ " => $next"),
            ) with self!happy($next, ($seq.Bool ?? $seq !! $n.Str) ~ " => $next");
        }
        return $n == 1
            ?? %(|%!happiness<1>, iter => 1, :seq($seq || "1"))
            !! %!happiness{$n} || is-happy();
    }

    method detail($n) {
        self!happy($n);
        %!happiness{$n};
    }

    method is-happy($n) {
        self.detail($n)<zhappy>;
    }

    method happiness() { %!happiness }
}

class HappySequence does Iterator does Iterable {
    has Int $.base is rw = 10;
    has Int $.power is rw = 2;

    has Int $!next-number = 1;
    has HappyEngine $!engine;

    submethod TWEAK() {
        $!engine = HappyNumbers::HappyEngine.new(:$!base, :$!power);
    }

    method iterator() { self }

    method pull-one() {
        loop {
            my $n = $!next-number;
            my $normalized = $!engine.normalize($n);
            if $!engine.is-happy($normalized) {
                $!next-number++;
                return $n;
            }
            $!next-number++;
        }
    }

    method is-lazy() { True }
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
    has @!pure-numbers;
    has Int $!max-tried;
    has @!sequences;
    has HappyEngine $!engine;

    submethod TWEAK() {
        $!engine = HappyNumbers::HappyEngine.new(:$!base, :$!power);
    }

    method calculate(:$limit) {
        @!happy-numbers = (1,);
        @!pure-numbers = ();
        @!sequences = ();
        $!engine = HappyNumbers::HappyEngine.new(:$!base, :$!power);

        my $normalizer = -> $n { $!engine.normalize($n) };

        for 2 .. * -> $number {
            my $normalized = $normalizer($number);
            my $detail = $!engine.detail($normalized);
            if $detail<zhappy> {
                @!happy-numbers.push($number);
                @!sequences.push($number => $detail<seq>);
            }
            last if @!happy-numbers.unique(:as($!get-pure ?? $normalizer !! *)).elems == $limit;
            LAST {
                $!max-tried = $number;
            }
        }

        @!pure-numbers = @!happy-numbers.unique(:as($normalizer));

        return %(
            :happy-numbers(@!happy-numbers),
            :pure-numbers(@!pure-numbers),
            :max-tried($!max-tried),
            :happiness($!engine.happiness()),
            :hash-size($!engine.happiness().elems),
            :sequences(@!sequences),
        );
    }

    method happy-sequence() {
        HappySequence.new(:$.base, :$.power)
    }

    method pure-sequence() {
        PureHappySequence.new(:$.base, :$.power)
    }

    method happiness() { $!engine.happiness() }
    method happy-numbers() { @!happy-numbers }
    method pure-numbers() { @!pure-numbers }
    method sequences() { @!sequences }
}
