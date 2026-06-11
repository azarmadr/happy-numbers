#! /usr/bin/env raku

use v6.d;
use lib 'lib';
use HappyNumbers;

my $FORM_HTML = 'templates.html'.IO.slurp;

my $host = '0.0.0.0';
my $port = 5000;

say "Starting Happy Numbers server on http://$host:$port/";

my $listen = IO::Socket::INET.new(:listen, :localhost($host), :localport($port));

loop {
    my $client = $listen.accept;
    my %params;
    if $client.get ~~ /'?' (\S*)/ {
        my $query = $0.Str;
        for $query.split('&') -> $pair {
            my ($k, $v) = $pair.split('=', 2);
            %params{$k} = $v // '';
        }
    }

    my $body = $FORM_HTML;
    my $content-type = 'text/html; charset=utf-8';

    if %params<limit base power>:k {
        %params = (:9limit, :10base, :2power, |%params);
        $_ .= Int for %params<limit base power>:v;
        my ($limit, $base, $power, $pure) = %params<limit base power pure>:v;

        $limit = 1 if $limit < 1;
        $limit = 1000 if $limit > 1000;
        $base = 2 if $base < 2;
        $base = 36 if $base > 36;
        $power = 1 if $power < 1;
        $power = 10 if $power > 10;

        my $seq = HappyNumbers::HappySeq.new(:$base, :$power);
        my $results-html = build-results-html(construct-rich $seq, |%params);

        $body .= subst('<!--RESULTS_PLACEHOLDER-->', $results-html);

        $body .= subst('value="9"', "value=\"$limit\"", :g);
        $body .= subst('value="10"', "value=\"$base\"", :g);
        $body .= subst('value="2"', "value=\"$power\"", :g);
        $body .= subst('name="pure" value="1"', 'name="pure" value="1"' ~ ($pure ?? ' checked' !! ''), :g);
    } else {
        $body .= subst('<!--RESULTS_PLACEHOLDER-->', '');
    }

    my $response = "HTTP/1.1 200 OK\r\n";
    $response ~= "Content-Type: $content-type\r\n";
    $response ~= "Content-Length: {$body.encode.bytes}\r\n";
    $response ~= "Connection: close\r\n";
    $response ~= "\r\n";
    $response ~= $body;

    $client.print($response);
    $client.close;
}

sub construct-rich($seq, :$pure, :$limit, :$base, :$power) {
    my @h = [$seq.pull-one :$pure for ^$limit];
    my %results = :happy-numbers(@h);
    %results<pure-numbers> = @h.grep({HappyNumbers::is-normalized($_) :$base});
    %results<graph> = $seq.graph;
    return %results
}

# HTML rendering subs
sub build-graph-html(%graph) {
    my @nodes = %graph.keys.sort: *.Int;
    return '' if @nodes.elems == 0;

    # Build children map: parent -> list of children (numbers that point to parent)
    my %children;
    for %graph.kv -> $num, $data {
        my $next = $data<next>;
        if $next.defined && $next.Str ~~ /^\d+$/ {
            %children{$next}.push($num);
        }
    }

    # ---- Decompose into connected components ----
    my %component;
    my $comp-id = 0;
    for @nodes -> $node {
        next if %component{$node}:exists;
        my @queue = ($node,);
        while @queue.elems > 0 {
            my $n = @queue.shift;
            next if %component{$n}:exists;
            %component{$n} = $comp-id;
            my $next = %graph{$n}<next>;
            if $next.defined && $next.Str ~~ /^\d+$/ && !(%component{$next.Str}:exists) {
                @queue.push($next.Str);
            }
            if (%children{$n}:exists) {
                for %children{$n}.list -> $child {
                    if !(%component{$child}:exists) {
                        @queue.push($child);
                    }
                }
            }
        }
        $comp-id++;
    }

    my %comp-nodes;
    for @nodes -> $node {
        %comp-nodes{%component{$node}}.push($node);
    }

    # ---- Constants ----
    my %pos;
    my %all-cycle-nodes;
    my $r = 16;
    my $petal-r = 26;
    my $cycle-r = 55;
    my $comp-gap = 60;
    my $comp-y = 120;
    my $comp-x = 0;

    sub node-color($node) {
        my $data = %graph{$node};
        return $data<happy> ?? '#4caf50' !! '#f44336';
    }

    # ---- Layout each component ----
    for ^$comp-id -> $cid {
        my @comp = %comp-nodes{$cid}.list.sort: *.Int;
        next if @comp.elems == 0;

        # Find the cycle
        my %visited;
        my %in-cycle;
        for @comp -> $start {
            next if %in-cycle{$start}:exists;
            my %path-seen;
            my $current = $start;
            my @path;
            loop {
                if %path-seen{$current}:exists {
                    my $idx = @path.first: * eq $current, :k;
                    if $idx.defined {
                        for @path[$idx..*] -> $c {
                            %in-cycle{$c} = True;
                        }
                    }
                    last;
                }
                if %visited{$current}:exists {
                    last;
                }
                %path-seen{$current} = True;
                @path.push($current);
                %visited{$current} = True;

                my $next = %graph{$current}<next>;
                if $next.defined && $next.Str ~~ /^\d+$/ {
                    $current = $next.Str;
                } else {
                    last;
                }
            }
        }

        my @cycle = @comp.grep({ %in-cycle{$_}:exists }).sort: *.Int;
        for @cycle -> $c { %all-cycle-nodes{$c} = True; }

        # ---- Place cycle nodes in a circle ----
        my $center-x = $comp-x + $cycle-r + 40;
        my $center-y = $comp-y;

        if @cycle.elems == 1 {
            %pos{@cycle[0]} = %(x => $center-x, y => $center-y);
        } else {
            my $n = @cycle.elems;
            for ^$n -> $i {
                my $angle = 2 * pi * $i / $n - pi / 2;
                my $cx = $center-x + $cycle-r * cos($angle);
                my $cy = $center-y + $cycle-r * sin($angle);
                %pos{@cycle[$i]} = %(x => $cx, y => $cy);
            }
        }

        # ---- Build predecessor tree for each petal ----
        my %sub-children;
        for @comp -> $node {
            next if %in-cycle{$node}:exists;
            my $next = %graph{$node}<next>;
            if $next.defined && $next.Str ~~ /^\d+$/ {
                %sub-children{$next.Str}.push($node);
            }
        }

        # Group petal roots by their cycle attachment
        my %petal-roots;
        for @comp -> $node {
            next if %in-cycle{$node}:exists;
            my $current = $node;
            my %seen;
            loop {
                if %in-cycle{$current}:exists {
                    %petal-roots{$current}.push($node);
                    last;
                }
                if %seen{$current}:exists {
                    last;
                }
                %seen{$current} = True;
                my $next = %graph{$current}<next>;
                if $next.defined && $next.Str ~~ /^\d+$/ {
                    $current = $next.Str;
                } else {
                    last;
                }
            }
        }

        sub count-branch-leaves($node, %seen) {
            if %sub-children{$node}:exists {
                my @valid = %sub-children{$node}.grep({ !(%seen{$_}:exists) });
                if @valid.elems > 0 {
                    my $total = 0;
                    for @valid -> $child {
                        my %s2 = %seen.clone;
                        %s2{$child} = True;
                        $total += count-branch-leaves($child, %s2);
                    }
                    return $total;
                }
            }
            return 1;
        }

        # Place each petal radially
        my $n-cycle = @cycle.elems;
        for ^$n-cycle -> $i {
            my $cycle-node = @cycle[$i];
            my @roots = %petal-roots{$cycle-node}:exists ?? %petal-roots{$cycle-node}.list !! ();
            next if @roots.elems == 0;

            my $base-angle = $n-cycle == 1
                ?? -pi / 2
                !! 2 * pi * $i / $n-cycle - pi / 2;

            my $spread = max(pi / 3, min(pi * 0.8, @roots.elems * pi / 8));
            my $start-angle = $base-angle - $spread / 2;
            my $step = $spread / max(1, @roots.elems);

            my %placed;
            sub place-radial($node, $angle, $depth, %seen) {
                my $dist = $cycle-r + $depth * $petal-r;
                my $px = $center-x + $dist * cos($angle);
                my $py = $center-y + $dist * sin($angle);
                %pos{$node} = %(x => $px, y => $py);
                %placed{$node} = True;

                if %sub-children{$node}:exists {
                    my @valid = %sub-children{$node}.grep({ !(%seen{$_}:exists) && !(%placed{$_}:exists) });
                    if @valid.elems > 0 {
                        my @counts;
                        for @valid -> $child {
                            my %s2 = %seen.clone;
                            %s2{$child} = True;
                            @counts.push(count-branch-leaves($child, %s2));
                        }
                        my $total = @counts.sum;
                        my $a-step = $spread / max(1, $total);
                        my $cur = $angle - ($spread / 2);
                        for ^@valid.elems -> $j {
                            my $child = @valid[$j];
                            my $ca = $cur + @counts[$j] * $a-step / 2;
                            my %s3 = %seen.clone;
                            %s3{$child} = True;
                            place-radial($child, $ca, $depth + 1, %s3);
                            $cur += @counts[$j] * $a-step;
                        }
                    }
                }
            }

            for ^@roots.elems -> $j {
                my $a = $start-angle + $step * ($j + 0.5);
                place-radial(@roots[$j], $a, 1, %(@roots[$j] => True));
            }
        }

        # Update component x for next component
        my $max-cx = 0;
        for @comp -> $n {
            if %pos{$n}:exists {
                $max-cx = max($max-cx, %pos{$n}<x> + $r + 20);
            }
        }
        $comp-x = $max-cx + $comp-gap;
    }

    # Dimensions
    my $max-x = 0;
    my $max-y = 0;
    my $min-x = 9999;
    my $min-y = 9999;
    for %pos.values -> $p {
        $max-x = max($max-x, $p<x>);
        $max-y = max($max-y, $p<y>);
        $min-x = min($min-x, $p<x>);
        $min-y = min($min-y, $p<y>);
    }
    my $margin = 30;
    my $width = $max-x - $min-x + $margin * 2;
    my $height = $max-y - $min-y + $margin * 2;

    for %pos.keys -> $k {
        %pos{$k}<x> -= $min-x - $margin;
        %pos{$k}<y> -= $min-y - $margin;
    }

    # ---- Render SVG ----
    sub edge-str($from, $to) {
        my $p1 = %pos{$from};
        my $p2 = %pos{$to};
        return '' unless $p1 && $p2;
        my $dx = $p2<x> - $p1<x>;
        my $dy = $p2<y> - $p1<y>;
        my $dist = sqrt($dx * $dx + $dy * $dy);
        return '' if $dist < 1;
        my $ux = $dx / $dist;
        my $uy = $dy / $dist;
        my $x1 = $p1<x> + $ux * $r;
        my $y1 = $p1<y> + $uy * $r;
        my $x2 = $p2<x> - $ux * $r;
        my $y2 = $p2<y> - $uy * $r;

        if $from eq $to {
            my $cx = $p1<x>;
            my $cy = $p1<y>;
            my $loop-r = $r + 6;
            my $sx = $cx;
            my $sy = $cy - $r;
            my $ex = $cx + 0.1;
            my $ey = $cy - $r;
            return '<path d="M ' ~ $sx ~ ',' ~ $sy ~ ' A ' ~ $loop-r ~ ' ' ~ $loop-r ~ ' 0 1 1 ' ~ $ex ~ ',' ~ $ey ~ '" fill="none" stroke="#888" stroke-width="1.5" marker-end="url(#arrow)" />';
        }

        # Cycle edges: curved arcs inward
        if (%all-cycle-nodes{$from}:exists) && (%all-cycle-nodes{$to}:exists) {
            my $mx = ($p1<x> + $p2<x>) / 2;
            my $my = ($p1<y> + $p2<y>) / 2;
            my $nx = $p2<x> - $p1<x>;
            my $ny = $p2<y> - $p1<y>;
            my $px = -$ny;
            my $py = $nx;
            my $plen = sqrt($px * $px + $py * $py);
            if $plen > 0 {
                $px /= $plen;
                $py /= $plen;
                my $offset = 25;
                my $qx = $mx + $px * $offset;
                my $qy = $my + $py * $offset;
                return '<path d="M ' ~ $x1 ~ ',' ~ $y1 ~ ' Q ' ~ $qx ~ ',' ~ $qy ~ ' ' ~ $x2 ~ ',' ~ $y2 ~ '" fill="none" stroke="#888" stroke-width="1.5" marker-end="url(#arrow)" />';
            }
        }

        return '<line x1="' ~ $x1 ~ '" y1="' ~ $y1 ~ '" x2="' ~ $x2 ~ '" y2="' ~ $y2 ~ '" stroke="#888" stroke-width="1.2" marker-end="url(#arrow)" />';
    }

    my $svg = '<svg xmlns="http://www.w3.org/2000/svg" width="' ~ $width ~ '" height="' ~ $height ~ '" viewBox="0 0 ' ~ $width ~ ' ' ~ $height ~ '" class="graph-svg">';
    $svg ~= '<defs>';
    $svg ~= '<marker id="arrow" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto"><polygon points="0 0, 8 3, 0 6" fill="#888" /></marker>';
    $svg ~= '</defs>';

    for @nodes -> $node {
        my $next = %graph{$node}<next>;
        if $next.defined && $next.Str ~~ /^\d+$/ && (%pos{$next.Str}:exists) {
            $svg ~= edge-str($node, $next.Str);
        }
    }

    for @nodes -> $node {
        my $p = %pos{$node};
        next unless $p;
        my $color = node-color($node);
        $svg ~= '<circle cx="' ~ $p<x> ~ '" cy="' ~ $p<y> ~ '" r="' ~ $r ~ '" fill="' ~ $color ~ '" stroke="#fff" stroke-width="1.5" />';
        $svg ~= '<text x="' ~ $p<x> ~ '" y="' ~ ($p<y> + 4) ~ '" text-anchor="middle" fill="#fff" font-size="11" font-family="monospace">' ~ $node ~ '</text>';
    }

    $svg ~= '</svg>';

    my $html = '<details>';
    $html ~= '<summary>Graph View</summary>';
    $html ~= '<div class="graph-container">';
    $html ~= $svg;
    $html ~= '<div class="graph-legend"><span class="legend-dot happy"></span> Happy <span class="legend-dot sad"></span> Sad</div>';
    $html ~= '</div>';
    $html ~= '</details>';
    return $html;
}

sub build-results-html($result) {
    my $html = '<div class="results">';
    $html ~= '<h2>Results</h2>';

    $html ~= '<div class="output-line">     Happy Numbers(' ~ $result<happy-numbers>.elems ~ '): ' ~ $result<happy-numbers>.join(', ') ~ '</div>';
    $html ~= '<div class="output-line">Pure Happy Numbers(' ~ $result<pure-numbers>.elems ~ '): ' ~ $result<pure-numbers>.join(', ') ~ '</div>';
    $html ~= '<div class="output-line">Max Number tried: ' ~ ($result<max-tried> // 'N/A') ~ '</div>';
    $html ~= '<div class="output-line">Hash size: ' ~ $result<hash-size> ~ '</div>';

    # Interactive hash table
    if $result<graph>.elems > 0 {
        $html ~= '<details>';
        $html ~= '<summary>Happiness Hash (' ~ $result<graph>.elems ~ ' entries)</summary>';
        $html ~= '<table class="hash-table">';
        $html ~= '<tr><th>Number</th><th>Next</th><th>Iterations</th><th>Happy?</th></tr>';
        for $result<graph>.sort: *.key.Int -> $p {
            my $key = $p.key;
            my $data = $p.value;
            my $next = $data<next> // 'N/A';
            my $iter = $data<iter> // 'N/A';
            my $is-happy = $data<happy> ?? 'Yes' !! 'No';
            my $next-link = $next ~~ /^\d+$/ ?? '<a onclick="jumpTo(' ~ $next ~ ')">' ~ $next ~ '</a>' !! $next;
            $html ~= '<tr id="num-' ~ $key ~ '"><td>' ~ $key ~ '</td><td>' ~ $next-link ~ '</td><td>' ~ $iter ~ '</td><td>' ~ $is-happy ~ '</td></tr>';
        }
        $html ~= '</table>';
        $html ~= '</details>';
    }

    # Graph view of the graph hash
    if $result<graph>.elems > 0 {
        $html ~= build-graph-html($result<graph>);
    }

    # Sequences
    if False && $result<sequences>.elems > 0 {
        $html ~= '<details>';
        $html ~= '<summary>Sequences (' ~ $result<sequences>.elems ~ ')</summary>';
        for @($result<sequences>) -> $seq {
            my $num = $seq.key;
            my $path = $seq.value;
            $html ~= '<div class="sequence-line"><span class="num">' ~ $num ~ '</span> <span class="arrow">=></span> ' ~ $path ~ '</div>';
        }
        $html ~= '</details>';
    }

    $html ~= '</div>';
    return $html;
}
