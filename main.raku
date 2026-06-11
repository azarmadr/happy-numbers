#! /usr/bin/env raku

use v6.d;
use lib 'lib';
use HappyNumbers;
use Graph;

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

sub build-results-html($result) {
    my $html = '<div class="results">';
    $html ~= '<h2>Results</h2>';

    $html ~= '<div class="output-line">     Happy Numbers(' ~ $result<happy-numbers>.elems ~ '): ' ~ $result<happy-numbers>.join(', ') ~ '</div>';
    $html ~= '<div class="output-line">Pure Happy Numbers(' ~ $result<pure-numbers>.elems ~ '): ' ~ $result<pure-numbers>.join(', ') ~ '</div>';
    $html ~= '<div class="output-line">Max Number tried: ' ~ ($result<max-tried> // 'N/A') ~ '</div>';
    $html ~= '<div class="output-line">Hash size: ' ~ $result<hash-size> ~ '</div>';

    # Interactive hash table
    if $result<graph>.elems > 0 {
        my @g = $result<graph><>:p.map({
            my $from = $_.key; my %r = %(:$from, |$_.value);
            %r<to> = %r<next>:delete.Str;
            %r
        });
        my $graph = Graph.new(@g, :directed);
        my @keys = q:w/from to happy/;# %(@g.first).keys;
        $html ~= '<details>';
        $html ~= '<summary>Happiness Hash (' ~ @g.elems ~ ' entries)</summary>';
        $html ~= '<table class="hash-table">';
        $html ~= '<tr>' ~ @keys.map('<th>' ~ *).join;
        for @g -> %data {
            $_ = '<a onclick="jumpTo(' ~ $_ ~ ')">' ~ $_ ~ '</a>' with %data<next>;
            $_ = $_ ?? 'Yes' !! 'No' with %data<happy>;
            dd %data{@keys};
            $html ~= '<tr id="num-' ~ %data<number> ~ '">' ~ @keys.map({'<td>' ~ %data{$_}});
            $html ~= "\n";
        }
        $html ~= '</table>';
        $html ~= '</details>';

        $html ~= '<details open>';
        $html ~= '<summary>Graph View</summary>';
        $html ~= '<div class="graph-container">';
        $html ~= $graph.dot(engine=>'neato', size=> 8):svg;
        $html ~= '<div class="graph-legend"><span class="legend-dot happy"></span> Happy <span class="legend-dot sad"></span> Sad</div>';
        $html ~= '</div>';
        $html ~= '</details>';
        # Graph view of the graph hash
        # $html ~= build-graph-html($result<graph>);
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
