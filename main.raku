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
sub build-graph-html(%happiness) {
    my @nodes = %happiness.keys.sort: *.Int;
    my $n = @nodes.elems;
    return '' if $n == 0;

    # Layout parameters
    my $cols = ($n <= 20) ?? 5 !! ($n <= 50) ?? 8 !! 10;
    my $spacing = 70;
    my $margin = 40;
    my $r = 22;
    my $rows = ceiling($n / $cols);
    my $width = $cols * $spacing + $margin * 2;
    my $height = $rows * $spacing + $margin * 2;

    # Position map
    my %pos;
    for @nodes.kv -> $i, $node {
        my $col = $i % $cols;
        my $row = floor($i / $cols);
        %pos{$node} = %(
            x => $margin + $col * $spacing + $spacing / 2,
            y => $margin + $row * $spacing + $spacing / 2,
        );
    }

    sub node-color($node) {
        my $data = %happiness{$node};
        return $data<zhappy> ?? '#4caf50' !! '#f44336';
    }

    sub edge-str($from, $to) {
        my $p1 = %pos{$from};
        my $p2 = %pos{$to};
        return '' unless $p1 && $p2;
        my $dx = $p2<x> - $p1<x>;
        my $dy = $p2<y> - $p1<y>;
        my $dist = sqrt($dx * $dx + $dy * $dy);
        return '' if $dist == 0;
        my $ux = $dx / $dist;
        my $uy = $dy / $dist;
        my $x1 = $p1<x> + $ux * $r;
        my $y1 = $p1<y> + $uy * $r;
        my $x2 = $p2<x> - $ux * $r;
        my $y2 = $p2<y> - $uy * $r;
        # For self-loops, draw a small circle above the node
        if $from eq $to {
            my $cx = $p1<x>;
            my $cy = $p1<y> - $r - 10;
            return '<path d="M ' ~ $cx ~ ',' ~ ($p1<y> - $r) ~ ' Q ' ~ ($cx - 20) ~ ',' ~ $cy ~ ' ' ~ $cx ~ ',' ~ $cy ~ ' Q ' ~ ($cx + 20) ~ ',' ~ $cy ~ ' ' ~ $cx ~ ',' ~ ($p1<y> - $r) ~ '" fill="none" stroke="#888" stroke-width="1.5" marker-end="url(#arrow)" />';
        }
        return '<line x1="' ~ $x1 ~ '" y1="' ~ $y1 ~ '" x2="' ~ $x2 ~ '" y2="' ~ $y2 ~ '" stroke="#888" stroke-width="1.5" marker-end="url(#arrow)" />';
    }

    my $svg = '<svg xmlns="http://www.w3.org/2000/svg" width="' ~ $width ~ '" height="' ~ $height ~ '" viewBox="0 0 ' ~ $width ~ ' ' ~ $height ~ '" class="graph-svg">';
    $svg ~= '<defs>';
    $svg ~= '<marker id="arrow" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto"><polygon points="0 0, 10 3.5, 0 7" fill="#888" /></marker>';
    $svg ~= '</defs>';

    # Edges first (so they go behind nodes)
    for @nodes -> $node {
        my $next = %happiness{$node}<next>;
        if $next.defined && $next.Str ~~ /^\d+$/ && (%pos{$next.Str}:exists) {
            $svg ~= edge-str($node, $next.Str);
        }
    }

    # Nodes
    for @nodes -> $node {
        my $p = %pos{$node};
        my $color = node-color($node);
        $svg ~= '<circle cx="' ~ $p<x> ~ '" cy="' ~ $p<y> ~ '" r="' ~ $r ~ '" fill="' ~ $color ~ '" stroke="#fff" stroke-width="2" />';
        $svg ~= '<text x="' ~ $p<x> ~ '" y="' ~ ($p<y> + 5) ~ '" text-anchor="middle" fill="#fff" font-size="13" font-family="monospace">' ~ $node ~ '</text>';
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

    # Graph view of the happiness hash
    if $result<happiness>.elems > 0 {
        $html ~= build-graph-html($result<happiness>);
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
