// WebAssembly Happy Numbers Calculator
// Bridges HTMX form submissions to WASM computations

import initWasm, * as wasm from './happy_numbers.js';

let wasmReady = false;

// Initialize WASM module
async function initializeWasm() {
    try {
        await initWasm();
        wasmReady = true;
        console.log('✓ WASM module loaded successfully');
    } catch (error) {
        console.error('Failed to load WASM:', error);
        showError('Failed to load WebAssembly module. Some features may be unavailable.');
    }
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
    initializeWasm();
    setupFormHandlers();
});

// Setup form event listeners
function setupFormHandlers() {
    const form = document.getElementById('calculate-form');
    const resetBtn = document.getElementById('reset-btn');

    form.addEventListener('submit', async (e) => {
        e.preventDefault();
        await handleCalculate();
    });

    resetBtn.addEventListener('click', () => {
        document.getElementById('results').innerHTML = '';
        document.getElementById('results').classList.remove('active');
        document.getElementById('loading').style.display = 'none';
    });
}

// Main calculation handler
async function handleCalculate() {
    if (!wasmReady) {
        showError('WASM module is not ready. Please refresh the page.');
        return;
    }

    // Get form values
    const limit = parseInt(document.getElementById('limit').value) || 9;
    const base = parseInt(document.getElementById('base').value) || 10;
    const pow = parseInt(document.getElementById('pow').value) || 2;
    const pure = document.getElementById('pure').checked;

    // Validate ranges
    const validLimit = Math.max(1, Math.min(1000, limit));
    const validBase = Math.max(2, Math.min(36, base));
    const validPow = Math.max(1, Math.min(10, pow));

    // Show loading
    showLoading(true);

    try {
        // Call WASM function
        const result = wasm.calculate_happy_numbers(validLimit, validBase, validPow, pure);

        // Parse and display results
        const parsed = JSON.parse(result);
        displayResults(parsed, validLimit, validBase, validPow, pure);

        showLoading(false);
    } catch (error) {
        console.error('Calculation error:', error);
        showError(`Calculation failed: ${error.message}`);
        showLoading(false);
    }
}

// Display results in HTML
function displayResults(result, limit, base, pow, pure) {
    const resultsDiv = document.getElementById('results');
    resultsDiv.classList.add('active');

    const happyCount = result.happy_numbers?.length || 0;
    const pureCount = result.pure_numbers?.length || 0;

    let html = `
        <div class="summary">
            <div class="summary-item">
                <span>Happy Numbers Found:</span>
                <strong>${happyCount}</strong>
            </div>
            <div class="summary-item">
                <span>Pure Happy Numbers:</span>
                <strong>${pureCount}</strong>
            </div>
            <div class="summary-item">
                <span>Range Checked:</span>
                <strong>1 to ${limit}</strong>
            </div>
            <div class="summary-item">
                <span>Base / Power:</span>
                <strong>${base} / ${pow}</strong>
            </div>
        </div>
    `;

    // Happy numbers list
    if (happyCount > 0) {
        html += `
            <details open>
                <summary>🎉 Happy Numbers (${happyCount})</summary>
                <div style="display: flex; flex-wrap: wrap; gap: 0.5rem; margin-top: 1rem;">
                    ${result.happy_numbers.map(n => `<span style="background: #d4edda; color: #155724; padding: 0.25rem 0.75rem; border-radius: 4px; font-weight: 600;">${n}</span>`).join('')}
                </div>
            </details>
        `;
    }

    // Pure numbers list
    if (pureCount > 0) {
        html += `
            <details>
                <summary>⭐ Pure Happy Numbers (${pureCount})</summary>
                <div style="display: flex; flex-wrap: wrap; gap: 0.5rem; margin-top: 1rem;">
                    ${result.pure_numbers.map(n => `<span style="background: #fff3cd; color: #856404; padding: 0.25rem 0.75rem; border-radius: 4px; font-weight: 600;">${n}</span>`).join('')}
                </div>
            </details>
        `;
    }

    // Hash table with details
    if (result.happiness && Object.keys(result.happiness).length > 0) {
        html += buildHashTable(result.happiness);
    }

    // Sequences
    if (result.sequences && result.sequences.length > 0) {
        html += buildSequences(result.sequences);
    }

    resultsDiv.innerHTML = html;
}

// Build interactive hash table
function buildHashTable(happiness) {
    const sorted = Object.entries(happiness)
        .sort((a, b) => parseInt(a[0]) - parseInt(b[0]));

    let html = `
        <details>
            <summary>📊 Happiness Hash Table (${sorted.length} entries)</summary>
            <table class="hash-table">
                <thead>
                    <tr>
                        <th>Number</th>
                        <th>Next</th>
                        <th>Iterations</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
    `;

    sorted.forEach(([num, data]) => {
        const next = data.next ?? 'N/A';
        const iter = data.iter ?? 'N/A';
        const status = data.zhappy ? '<span class="happy">✓ Happy</span>' : '<span class="sad">✗ Sad</span>';

        html += `
            <tr id="num-${num}">
                <td><strong>${num}</strong></td>
                <td>${next}</td>
                <td>${iter}</td>
                <td>${status}</td>
            </tr>
        `;
    });

    html += `
                </tbody>
            </table>
        </details>
    `;

    return html;
}

// Build sequences display
function buildSequences(sequences) {
    let html = `
        <details>
            <summary>➡️ Calculation Sequences (${sequences.length})</summary>
            <div style="margin-top: 1rem;">
    `;

    sequences.slice(0, 20).forEach(seq => {
        const [num, path] = typeof seq === 'object' ? [seq.key || seq[0], seq.value || seq[1]] : seq;
        html += `
            <div class="sequence-line">
                <span class="sequence-number">${num}</span>
                <span class="sequence-arrow">→</span>
                <span>${path}</span>
            </div>
        `;
    });

    if (sequences.length > 20) {
        html += `<p style="margin-top: 1rem; color: #666; font-size: 0.9rem;">... and ${sequences.length - 20} more sequences</p>`;
    }

    html += `
            </div>
        </details>
    `;

    return html;
}

// Show/hide loading spinner
function showLoading(show) {
    document.getElementById('loading').style.display = show ? 'flex' : 'none';
}

// Show error message
function showError(message) {
    const resultsDiv = document.getElementById('results');
    resultsDiv.classList.add('active');
    resultsDiv.innerHTML = `
        <div class="error">
            <strong>⚠️ Error:</strong> ${message}
        </div>
    `;
}

// Export for testing
window.happyNumbersApp = {
    calculate: handleCalculate,
    showLoading,
    showError
};
