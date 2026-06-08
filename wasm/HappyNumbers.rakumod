use v6.d;

# Raku Happy Numbers Calculator - WASM Target
# Compiles to WebAssembly and returns rendered HTML

use JSON::Fast;

#| Parse URL-encoded form data
sub parse-form-data(Str $body --> Hash) {
    my %params;
    
    for $body.split('&') -> $pair {
        my ($key, $value) = $pair.split('=', 2);
        $key = $key.subst('+', ' ', :g).decode('utf-8-c8');
        $value = ($value // '').subst('+', ' ', :g).decode('utf-8-c8');
        %params{$key} = $value;
    }
    
    return %params;
}

#| Calculate sum of digit powers in given base
sub digit-power-sum(Int $n, Int $base, Int $power --> Int) {
    my Int $sum = 0;
    my Int $num = $n;
    
    while $num > 0 {
        my Int $digit = $num mod $base;
        $sum += $digit ** $power;
        $num = $num div $base;
    }
    
    return $sum;
}

#| Build happiness map
sub build-happiness-map(Int $limit, Int $base, Int $power --> Hash) {
    my %happiness;
    
    for 1 .. $limit -> Int $n {
        my @path;
        my Int $current = $n;
        my Set $seen .= new;
        
        while $current != 1 && $current ∉ $seen {
            @path.push($current);
            $seen.add($current);
            $current = digit-power-sum($current, $base, $power);
        }
        
        @path.push($current);
        
        my Bool $is-happy = $current == 1;
        %happiness{$n} = {
            next => $current,
            iter => @path.elems,
            zhappy => $is-happy,
            path => @path
        };
    }
    
    return %happiness;
}

#| Build HTML for happy numbers list
sub build-happy-list(@happy --> Str) {
    return '<details open>' ~
           '<summary>🎉 Happy Numbers (' ~ @happy.elems ~ ')</summary>' ~
           '<div style="display: flex; flex-wrap: wrap; gap: 0.5rem; margin-top: 1rem;">' ~
           @happy.map({ '<span style="background: #d4edda; color: #155724; padding: 0.25rem 0.75rem; border-radius: 4px; font-weight: 600;">' ~ $_ ~ '</span>' }).join('') ~
           '</div></details>';
}

#| Build HTML for hash table
sub build-hash-table(%happiness --> Str) {
    my @sorted = %happiness.sort(*.key.Int);
    my Str $html = '<details><summary>📊 Happiness Hash Table (' ~ @sorted.elems ~ ' entries)</summary>' ~
                   '<table class="hash-table"><thead><tr><th>Number</th><th>Next</th><th>Iterations</th><th>Status</th></tr></thead><tbody>';
    
    for @sorted -> $pair {
        my $num = $pair.key;
        my $data = $pair.value;
        my $next = $data<next> // 'N/A';
        my $iter = $data<iter> // 'N/A';
        my $status = $data<zhappy> ?? '<span class="happy">✓ Happy</span>' !! '<span class="sad">✗ Sad</span>';
        
        $html ~= '<tr id="num-' ~ $num ~ '"><td><strong>' ~ $num ~ '</strong></td><td>' ~ $next ~ '</td><td>' ~ $iter ~ '</td><td>' ~ $status ~ '</td></tr>';
    }
    
    $html ~= '</tbody></table></details>';
    return $html;
}

#| Build HTML for sequences
sub build-sequences(%sequences --> Str) {
    my Str $html = '<details><summary>➡️ Calculation Sequences (' ~ %sequences.elems ~ ')</summary><div style="margin-top: 1rem;">';
    
    my Int $count = 0;
    for %sequences.sort(*.key.Int) -> $pair {
        last if $count >= 20;
        my $num = $pair.key;
        my $path = $pair.value;
        $html ~= '<div class="sequence-line"><span class="sequence-number">' ~ $num ~ '</span><span class="sequence-arrow">→</span><span>' ~ $path ~ '</span></div>';
        $count++;
    }
    
    if %sequences.elems > 20 {
        $html ~= '<p style="margin-top: 1rem; color: #666; font-size: 0.9rem;">... and ' ~ (%sequences.elems - 20) ~ ' more sequences</p>';
    }
    
    $html ~= '</div></details>';
    return $html;
}

#| Render happy numbers as HTML
sub render-results(
    Int $limit, 
    Int $base, 
    Int $power, 
    Bool $pure = False
) is export returns Str {
    # Validate inputs
    my Int $valid-limit = ($limit max 1) min 1000;
    my Int $valid-base = ($base max 2) min 36;
    my Int $valid-power = ($power max 1) min 10;
    
    my %happiness = build-happiness-map($valid-limit, $valid-base, $valid-power);
    
    # Collect happy numbers and sequences
    my @happy;
    my %sequences;
    
    for %happiness.sort(*.key.Int) -> $pair {
        my $num = $pair.key;
        my $data = $pair.value;
        
        if $data<zhappy> {
            @happy.push($num);
        }
        
        %sequences{$num} = $data<path>.join(' → ');
    }
    
    # Build summary
    my Str $html = '<div class="summary">' ~
        '<div class="summary-item"><span>Happy Numbers Found:</span><strong>' ~ @happy.elems ~ '</strong></div>' ~
        '<div class="summary-item"><span>Range Checked:</span><strong>1 to ' ~ $valid-limit ~ '</strong></div>' ~
        '<div class="summary-item"><span>Base / Power:</span><strong>' ~ $valid-base ~ ' / ' ~ $valid-power ~ '</strong></div>' ~
        '<div class="summary-item"><span>Unique Numbers:</span><strong>' ~ %happiness.elems ~ '</strong></div>' ~
        '</div>';
    
    # Add happy numbers list
    if @happy.elems > 0 {
        $html ~= build-happy-list(@happy);
    }
    
    # Add hash table
    if %happiness.elems > 0 {
        $html ~= build-hash-table(%happiness);
    }
    
    # Add sequences
    if %sequences.elems > 0 {
        $html ~= build-sequences(%sequences);
    }
    
    return $html;
}

#| Parse form data and render - WASM entry point
sub calculate-and-render(Str $form-body) is export returns Str {
    my %params = parse-form-data($form-body);
    
    my Int $limit = (%params<limit> // '100').Int;
    my Int $base = (%params<base> // '10').Int;
    my Int $power = (%params<pow> // '2').Int;
    my Bool $pure = %params<pure>.defined && %params<pure> ne '';
    
    return render-results($limit, $base, $power, $pure);
}
