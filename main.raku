#! /usr/bin/env raku

unit sub MAIN (
:l(:$limit) = 9, :b(:$base) = 10, 
:p(:$pow) = 2, :r(:$get-pure), 
:v(:$verbose));

my @happy = 1;
my %happiness = 1 => %(next=>1,iter=>0,:zhappy);

my $normalize-num = *.base($base).comb.grep(*!~~0).sort.join.parse-base($base);

for 2 .. * -> $number {
  @happy.push($number) if happy($normalize-num($number))<zhappy>;

  print "$number Happy(",@happy.elems,") Pure-Happy(",@happy.unique(:as($normalize-num)).elems,")\e[0G" if $verbose;

  last if @happy.unique(:as($get-pure??$normalize-num!!*)).elems==$limit;

  LAST {
    say "\e[MMax Number tried ", $number if $verbose
  }
}

say $_ for %happiness.grep({$verbose}).sort: *.key.Int;

say "     Happy Numbers(", $_.elems, "): ", $_.join(", ") with @happy;
say "Pure Happy Numbers(", $_.elems, "): ", $_.join(", ") with @happy.unique(:as($normalize-num));

say "Hash size: ",%happiness.elems if $verbose;

sub happy($n, $seq = ""){
  say "\e[M"~:$seq~" (%happiness{$n}<iter>)" if $seq && %happiness{$n} && $verbose;
  my sub is-happy {
    my $next = $normalize-num($n.base($base).comb.map( *.parse-base($base) ** $pow).sum);
    %happiness{$n} = %(iter=>1);
    return %happiness{$n} = %(|%($_),:$next,iter=>$_<iter>+1) with happy($next, ($seq.Bool ?? $seq !! $n) ~ " => $next");
  }
  return $n == 1 ?? %(|%happiness<1>, iter=>1) !! %happiness{$n} || is-happy()
}