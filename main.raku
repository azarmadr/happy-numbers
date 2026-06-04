#! /usr/bin/env raku

use v6.d;

# HTML form page
my $FORM_HTML = Q:to/END/;
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Happy Numbers Calculator</title>
<style>
  * { box-sizing: border-box; }
  body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    min-height: 100vh;
    margin: 0;
    display: flex;
    justify-content: center;
    align-items: center;
    padding: 20px;
  }
  .container {
    background: #fff;
    border-radius: 16px;
    box-shadow: 0 10px 40px rgba(0,0,0,0.2);
    max-width: 600px;
    width: 100%;
    padding: 40px;
  }
  h1 {
    text-align: center;
    color: #333;
    margin-bottom: 8px;
  }
  p.subtitle {
    text-align: center;
    color: #666;
    margin-top: 0;
    margin-bottom: 28px;
  }
  label {
    display: block;
    margin-bottom: 6px;
    color: #444;
    font-weight: 600;
  }
  input[type="number"], input[type="text"] {
    width: 100%;
    padding: 12px 14px;
    border: 2px solid #e0e0e0;
    border-radius: 8px;
    font-size: 1rem;
    margin-bottom: 18px;
    transition: border-color 0.2s;
  }
  input[type="number"]:focus, input[type="text"]:focus {
    outline: none;
    border-color: #667eea;
  }
  .checkbox-row {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-bottom: 18px;
  }
  input[type="checkbox"] {
    width: 20px;
    height: 20px;
    accent-color: #667eea;
  }
  button {
    width: 100%;
    padding: 14px;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: #fff;
    border: none;
    border-radius: 8px;
    font-size: 1.1rem;
    font-weight: 600;
    cursor: pointer;
    transition: transform 0.15s, box-shadow 0.15s;
  }
  button:hover {
    transform: translateY(-2px);
    box-shadow: 0 6px 20px rgba(102,126,234,0.4);
  }
  .results {
    margin-top: 28px;
    padding: 20px;
    background: #f8f9fa;
    border-radius: 10px;
    border-left: 4px solid #667eea;
  }
  .results h2 {
    margin-top: 0;
    color: #333;
    font-size: 1.2rem;
  }
  .number-list {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin: 12px 0;
  }
  .number-tag {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: #fff;
    padding: 6px 12px;
    border-radius: 20px;
    font-size: 0.95rem;
    font-weight: 600;
  }
  .stat-row {
    display: flex;
    justify-content: space-between;
    padding: 8px 0;
    border-bottom: 1px solid #e0e0e0;
    font-size: 0.95rem;
  }
  .stat-row:last-child {
    border-bottom: none;
  }
  .stat-label {
    color: #666;
  }
  .stat-value {
    color: #333;
    font-weight: 600;
  }
  .info {
    margin-top: 20px;
    padding: 14px;
    background: #e3f2fd;
    border-radius: 8px;
    color: #1565c0;
    font-size: 0.9rem;
  }
  .info strong {
    color: #0d47a1;
  }
  .footer {
    text-align: center;
    margin-top: 24px;
    color: #888;
    font-size: 0.85rem;
  }
  .verbose-table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 10px;
    font-size: 0.85rem;
  }
  .verbose-table th, .verbose-table td {
    border: 1px solid #ddd;
    padding: 6px 10px;
    text-align: left;
  }
  .verbose-table th {
    background: #667eea;
    color: #fff;
  }
  .verbose-table tr:nth-child(even) {
    background: #f5f5f5;
  }
</style>
</head>
<body>
<div class="container">
  <h1>Happy Numbers Calculator</h1>
  <p class="subtitle">Find happy numbers with custom parameters</p>
  <form method="GET" action="/">
    <label for="limit">Limit (how many happy numbers to find)</label>
    <input type="number" id="limit" name="limit" value="9" min="1" max="1000">

    <label for="base">Base (number base, e.g. 10)</label>
    <input type="number" id="base" name="base" value="10" min="2" max="36">

    <label for="pow">Power (sum of digits raised to this power)</label>
    <input type="number" id="pow" name="pow" value="2" min="1" max="10">

    <div class="checkbox-row">
      <input type="checkbox" id="pure" name="pure" value="1">
      <label for="pure" style="margin-bottom:0;">Show pure happy numbers (unique by digit signature)</label>
    </div>

    <div class="checkbox-row">
      <input type="checkbox" id="verbose" name="verbose" value="1">
      <label for="verbose" style="margin-bottom:0;">Verbose mode (show internal computation)</label>
    </div>

    <button type="submit">Calculate Happy Numbers</button>
  </form>

  <!--RESULTS_PLACEHOLDER-->

  <div class="info">
    <strong>What are happy numbers?</strong> A happy number is defined by the process of replacing the number by the sum of the squares of its digits, and repeating until the number equals 1 (happy) or loops endlessly in a cycle (unhappy). <strong>1</strong> is a happy number.
  </div>

  <div class="footer">
    Powered by Raku
  </div>
</div>
</body>
</html>
END

# Simple HTTP server
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
        # Run calculation with provided parameters
        my $limit = (%params<limit> || 9).Int;
        my $base = (%params<base> || 10).Int;
        my $pow = (%params<pow> || 2).Int;
        my $get-pure = %params<pure> ?? True !! False;
        my $verbose = %params<verbose> ?? True !! False;

        # Clamp values for safety
        $limit = 1 if $limit < 1;
        $limit = 1000 if $limit > 1000;
        $base = 2 if $base < 2;
        $base = 36 if $base > 36;
        $pow = 1 if $pow < 1;
        $pow = 10 if $pow > 10;

        my $result = calculate-happy-numbers(:$limit, :$base, :$pow, :$get-pure, :$verbose);

        # Build results HTML
        my $results-html = build-results-html($result, :$verbose);

        # Build response page
        $body = $FORM_HTML;
        $body .= subst('<!--RESULTS_PLACEHOLDER-->', $results-html);

        # Update form values with submitted params
        $body .= subst('value="9"', "value=\"$limit\"", :g);
        $body .= subst('value="10"', "value=\"$base\"", :g);
        $body .= subst('value="2"', "value=\"$pow\"", :g);
        $body .= subst('name="pure" value="1"', 'name="pure" value="1"' ~ ($get-pure ?? ' checked' !! ''), :g);
        $body .= subst('name="verbose" value="1"', 'name="verbose" value="1"' ~ ($verbose ?? ' checked' !! ''), :g);
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

sub build-results-html($result, :$verbose) {
    my $html = '<div class="results">';
    $html ~= '<h2>Results</h2>';

    # Stats
    $html ~= '<div class="stat-row"><span class="stat-label">Happy Numbers Found:</span><span class="stat-value">' ~ $result<happy-numbers>.elems ~ '</span></div>';
    $html ~= '<div class="stat-row"><span class="stat-label">Pure Happy Numbers:</span><span class="stat-value">' ~ $result<pure-numbers>.elems ~ '</span></div>';
    $html ~= '<div class="stat-row"><span class="stat-label">Max Number Tried:</span><span class="stat-value">' ~ ($result<max-tried> // 'N/A') ~ '</span></div>';

    # Happy numbers list
    $html ~= '<h3 style="margin-top:16px;margin-bottom:8px;color:#333;font-size:1rem;">Happy Numbers</h3>';
    $html ~= '<div class="number-list">';
    for $result<happy-numbers> -> $n {
        $html ~= '<span class="number-tag">' ~ $n ~ '</span>';
    }
    $html ~= '</div>';

    # Pure numbers list
    $html ~= '<h3 style="margin-top:16px;margin-bottom:8px;color:#333;font-size:1rem;">Pure Happy Numbers</h3>';
    $html ~= '<div class="number-list">';
    for $result<pure-numbers> -> $n {
        $html ~= '<span class="number-tag">' ~ $n ~ '</span>';
    }
    $html ~= '</div>';

    # Verbose table
    if $verbose && $result<happiness>.elems > 0 {
        $html ~= '<h3 style="margin-top:16px;margin-bottom:8px;color:#333;font-size:1rem;">Computation Details</h3>';
        $html ~= '<table class="verbose-table">';
        $html ~= '<tr><th>Number</th><th>Next</th><th>Iterations</th><th>Happy?</th></tr>';
        for $result<happiness>.sort: *.key.Int -> $p {
            my $key = $p.key;
            my $data = $p.value;
            my $next = $data<next> // 'N/A';
            my $iter = $data<iter> // 'N/A';
            my $is-happy = $data<zhappy> ?? 'Yes' !! 'No';
            $html ~= '<tr><td>' ~ $key ~ '</td><td>' ~ $next ~ '</td><td>' ~ $iter ~ '</td><td>' ~ $is-happy ~ '</td></tr>';
        }
        $html ~= '</table>';
    }

    $html ~= '</div>';
    return $html;
}

# Extracted happy numbers calculation logic
sub calculate-happy-numbers(:$limit, :$base, :$pow, :$get-pure, :$verbose) {
    my @happy = 1;
    my %happiness = 1 => %(next=>1, iter=>0, :zhappy);
    my $max-tried;

    my $normalize-num = *.base($base).comb.grep(* !~~ 0).sort.join.parse-base($base);

    for 2 .. * -> $number {
        @happy.push($number) if happy($normalize-num($number), :%happiness, :$normalize-num, :$base, :$pow)<zhappy>;
        last if @happy.unique(:as($get-pure ?? $normalize-num !! *)).elems == $limit;
        LAST {
            $max-tried = $number;
        }
    }

    my @pure = @happy.unique(:as($normalize-num));

    return %(
        :happy-numbers(@happy),
        :pure-numbers(@pure),
        :max-tried($max-tried),
        :happiness(%happiness),
        :hash-size(%happiness.elems),
    );
}

sub happy($n, $seq = "", :%happiness, :$normalize-num, :$base, :$pow) {
    my sub is-happy {
        my $next = $normalize-num($n.base($base).comb.map(*.parse-base($base) ** $pow).sum);
        %happiness{$n} = %(iter => 1);
        return %happiness{$n} = %(|%($_), :$next, iter => $_<iter> + 1)
            with happy($next, ($seq.Bool ?? $seq !! $n) ~ " => $next", :%happiness, :$normalize-num, :$base, :$pow);
    }
    return $n == 1 ?? %(|%happiness<1>, iter => 1) !! %happiness{$n} || is-happy()
}
