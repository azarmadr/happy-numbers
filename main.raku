#! /usr/bin/env raku

use v6.d;

# Load HTML template from external file
my $FORM_HTML = 'templates.html'.IO.e ?? 'templates.html'.IO.slurp !! default-template();

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

# Fallback template if file is missing
sub default-template() {
    return Q:to/END/;
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Happy Numbers Calculator</title>
<style>
  body { font-family: sans-serif; background: #667eea; display: flex; justify-content: center; padding: 20px; }
  .container { background: #fff; border-radius: 16px; padding: 40px; max-width: 600px; width: 100%; }
  button { width: 100%; padding: 14px; background: #667eea; color: #fff; border: none; border-radius: 8px; font-size: 1.1rem; cursor: pointer; }
  input { width: 100%; padding: 12px; margin-bottom: 12px; border-radius: 8px; border: 1px solid #ccc; }
  .results { margin-top: 20px; padding: 20px; background: #f8f9fa; border-radius: 10px; }
</style>
</head>
<body>
<div class="container">
  <h1>Happy Numbers Calculator</h1>
  <form method="GET" action="/">
    <label>Limit</label><input type="number" name="limit" value="9">
    <label>Base</label><input type="number" name="base" value="10">
    <label>Power</label><input type="number" name="pow" value="2">
    <button type="submit">Calculate</button>
  </form>
  <!--RESULTS_PLACEHOLDER-->
</div>
</body>
</html>
END
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
