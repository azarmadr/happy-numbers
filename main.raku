#! /usr/bin/env raku

use v6.d;
use lib 'lib';
use HappyNumbers;

my $FORM_HTML = 'templates.html'.IO.e ?? 'templates.html'.IO.slurp !! default-template();

my $host = '0.0.0.0';
my $port = 5000;

say "Starting Happy Numbers server on http://$host:$port/";

my $listen = IO::Socket::INET.new(:listen, :localhost($host), :localport($port));

loop {
    my $client = $listen.accept;
    my $request = '';
    while my $line = $client.get {
        $request ~= $line ~ "\r\n";
        last if $line eq '';
    }

    my ($method, $path) = $request ~~ /^(\w+) \s+ (\S+) / ?? ($0, $1) !! ('GET', '/');

    my %params;
    if $path ~~ /'?' (.*)/ {
        my $query = $0.Str;
        for $query.split('&') -> $pair {
            my ($k, $v) = $pair.split('=', 2);
            %params{$k} = $v // '';
        }
    }

    my $body;
    my $content-type = 'text/html; charset=utf-8';

    if %params<limit> || %params<base> || %params<pow> {
        my $limit = (%params<limit> || 9).Int;
        my $base = (%params<base> || 10).Int;
        my $pow = (%params<pow> || 2).Int;
        my $get-pure = %params<pure> ?? True !! False;

        $limit = 1 if $limit < 1;
        $limit = 1000 if $limit > 1000;
        $base = 2 if $base < 2;
        $base = 36 if $base > 36;
        $pow = 1 if $pow < 1;
        $pow = 10 if $pow > 10;

        my $calc = HappyNumbers::Calculator.new(:$limit, :$base, :power($pow), :$get-pure);
        my $result = $calc.calculate();

        my $results-html = build-results-html($result);

        $body = $FORM_HTML;
        $body .= subst('<!--RESULTS_PLACEHOLDER-->', $results-html);

        $body .= subst('value="9"', "value=\"$limit\"", :g);
        $body .= subst('value="10"', "value=\"$base\"", :g);
        $body .= subst('value="2"', "value=\"$pow\"", :g);
        $body .= subst('name="pure" value="1"', 'name="pure" value="1"' ~ ($get-pure ?? ' checked' !! ''), :g);
    } else {
        $body = $FORM_HTML;
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

# HTML rendering subs
sub build-tree-html(%happiness) {
    # Build reverse mapping: each number -> list of numbers that map to it
    my %children;
    for %happiness.kv -> $num, $data {
        my $next = $data<next>;
        if $next.defined && $next.Str ~~ /^\d+$/ {
            %children{$next}.push($num);
        }
    }

    # Find roots: nodes that are not a "next" value of any OTHER node
    # (Self-loops are included as roots even if they point to themselves)
    my %is-child;
    for %happiness.kv -> $num, $data {
        my $next = $data<next>;
        if $next.defined && $next.Str ~~ /^\d+$/ && $next.Str ne $num {
            %is-child{$num} = True;
        }
    }
    my @roots = %happiness.keys.grep({ !(%is-child{$_}:exists) }).sort: *.Int;

    sub render-node($node, %seen) {
        my $data = %happiness{$node};
        my $is-happy = $data<zhappy> ?? 'happy' !! 'sad';
        my $html = '<div class="tree-node">' ~ $node;
        $html ~= ' <span class="tree-tag ' ~ $is-happy ~ '">' ~ $is-happy ~ '</span>';
        if (%children{$node}:exists) {
            $html ~= '<div class="tree-children">';
            for %children{$node}.sort: *.Int -> $child {
                next if $child eq $node; # skip self-loop children
                next if (%seen{$child}:exists); # prevent cycles
                my %seen-new = %seen.clone;
                %seen-new{$child} = True;
                $html ~= render-node($child, %seen-new);
            }
            $html ~= '</div>';
        }
        $html ~= '</div>';
        return $html;
    }

    # Track all nodes included in the tree from roots
    my %included;
    for @roots -> $root {
        %included{$root} = True;
        sub mark-children($node, %seen) {
            if (%children{$node}:exists) {
                for %children{$node}.sort: *.Int -> $child {
                    next if $child eq $node;
                    next if (%seen{$child}:exists);
                    %included{$child} = True;
                    my %seen-new = %seen.clone;
                    %seen-new{$child} = True;
                    mark-children($child, %seen-new);
                }
            }
        }
        my %seen-root = %($root => True);
        mark-children($root, %seen-root);
    }

    # Add disconnected cyclic components (e.g. sad cycle with no entry point)
    my @remaining = %happiness.keys.grep({ !(%included{$_}:exists) }).sort: *.Int;
    while @remaining.elems > 0 {
        my $start = @remaining[0];
        # Find the cycle: walk from start until we loop
        my %cycle-seen;
        my $current = $start;
        my $cycle-root;
        loop {
            if (%cycle-seen{$current}:exists) {
                $cycle-root = $current;
                last;
            }
            %cycle-seen{$current} = True;
            my $next = %happiness{$current}<next>;
            if $next.defined && $next.Str ~~ /^\d+$/ {
                $current = $next.Str;
            } else {
                last;
            }
        }
        @roots.push($cycle-root) if $cycle-root.defined;
        # Recompute remaining
        %included = %();
        for @roots -> $root {
            %included{$root} = True;
            sub mark-children2($node, %seen) {
                if (%children{$node}:exists) {
                    for %children{$node}.sort: *.Int -> $child {
                        next if $child eq $node;
                        next if (%seen{$child}:exists);
                        %included{$child} = True;
                        my %seen-new = %seen.clone;
                        %seen-new{$child} = True;
                        mark-children2($child, %seen-new);
                    }
                }
            }
            my %seen-root = %($root => True);
            mark-children2($root, %seen-root);
        }
        @remaining = %happiness.keys.grep({ !(%included{$_}:exists) }).sort: *.Int;
    }

    my $html = '<details>';
    $html ~= '<summary>Tree View</summary>';
    $html ~= '<div class="tree-view">';
    for @roots -> $root {
        my %seen = %($root => True);
        $html ~= render-node($root, %seen);
    }
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
    if $result<happiness>.elems > 0 {
        $html ~= '<details>';
        $html ~= '<summary>Happiness Hash (' ~ $result<happiness>.elems ~ ' entries)</summary>';
        $html ~= '<table class="hash-table">';
        $html ~= '<tr><th>Number</th><th>Next</th><th>Iterations</th><th>Happy?</th></tr>';
        for $result<happiness>.sort: *.key.Int -> $p {
            my $key = $p.key;
            my $data = $p.value;
            my $next = $data<next> // 'N/A';
            my $iter = $data<iter> // 'N/A';
            my $is-happy = $data<zhappy> ?? 'Yes' !! 'No';
            my $next-link = $next ~~ /^\d+$/ ?? '<a onclick="jumpTo(' ~ $next ~ ')">' ~ $next ~ '</a>' !! $next;
            $html ~= '<tr id="num-' ~ $key ~ '"><td>' ~ $key ~ '</td><td>' ~ $next-link ~ '</td><td>' ~ $iter ~ '</td><td>' ~ $is-happy ~ '</td></tr>';
        }
        $html ~= '</table>';
        $html ~= '</details>';
    }

    # Tree view of the happiness hash
    if $result<happiness>.elems > 0 {
        $html ~= build-tree-html($result<happiness>);
    }

    # Sequences
    if $result<sequences>.elems > 0 {
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

sub default-template() {
    return Q:to/END/;
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Happy Numbers</title>
<style>
  body { font-family: sans-serif; background: #fafafa; color: #222; max-width: 720px; margin: 0 auto; padding: 24px; }
  h1 { font-size: 1.5rem; }
  .subtitle { color: #666; font-size: 0.9rem; }
  details { background: #fff; border: 1px solid #ddd; border-radius: 6px; padding: 12px 16px; margin-bottom: 16px; }
  summary { font-weight: 600; cursor: pointer; }
  .form-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; }
  input { padding: 8px; border: 1px solid #ccc; border-radius: 4px; }
  button { width: 100%; padding: 10px; background: #222; color: #fff; border: none; border-radius: 4px; }
  .results { background: #fff; border: 1px solid #ddd; border-radius: 6px; padding: 16px; }
  .output-line { font-family: monospace; font-size: 0.9rem; padding: 4px 0; border-bottom: 1px solid #f0f0f0; }
  .sequence-line { font-family: monospace; font-size: 0.85rem; padding: 6px; background: #f8f8f8; border-radius: 4px; margin-bottom: 6px; }
  .hash-table { width: 100%; border-collapse: collapse; font-size: 0.85rem; }
  .hash-table th, .hash-table td { padding: 6px; border-bottom: 1px solid #eee; }
  .hash-table a { color: #1565c0; text-decoration: underline; cursor: pointer; }
  .footer { text-align: center; color: #888; font-size: 0.8rem; margin-top: 24px; }
</style>
<script>
  function jumpTo(id) {
    var el = document.getElementById('num-' + id);
    if (el) {
      el.scrollIntoView({ behavior: 'smooth', block: 'center' });
      el.classList.add('highlight');
      setTimeout(function() { el.classList.remove('highlight'); }, 1200);
    }
  }
</script>
</head>
<body>
  <h1>Happy Numbers</h1>
  <p class="subtitle">Find happy numbers with custom parameters</p>
  <details><summary>Parameters</summary>
    <form method="GET" action="/">
      <div class="form-grid">
        <div><label>Limit</label><input type="number" name="limit" value="9"></div>
        <div><label>Base</label><input type="number" name="base" value="10"></div>
        <div><label>Power</label><input type="number" name="pow" value="2"></div>
      </div>
      <button type="submit">Calculate</button>
    </form>
  </details>
  <!--RESULTS_PLACEHOLDER-->
  <div class="footer">Powered by Raku</div>
</body>
</html>
END
}
