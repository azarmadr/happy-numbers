import init, * as wasm from './happy_numbers_bg.wasm';

let wasmReady = false;

// Initialize WASM module
async function initializeWasm() {
    try {
        await init();
        wasmReady = true;
        console.log('✓ WASM module loaded successfully');
        enableForm();
    } catch (error) {
        console.error('Failed to load WASM:', error);
        showError('Failed to load WebAssembly module. This app requires WASM support.');
        disableForm();
    }
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', initializeWasm);

// Intercept HTMX requests and hand off to WASM
document.body.addEventListener('htmx:ajax:beforeSend', (event) => {
    if (event.detail.xhr.url === '/calculate' && wasmReady) {
        event.preventDefault();
        
        try {
            // Pass raw form data to WASM - it handles everything
            const formBody = event.detail.requestConfig.request.body;
            const html = wasm.calculate_and_render(formBody);
            
            // HTMX swap
            const target = document.querySelector(event.detail.target);
            if (target) {
                target.innerHTML = html;
                target.classList.add('active');
                htmx.process(target);
            }
        } catch (error) {
            console.error('WASM calculation error:', error);
            showError(`Calculation failed: ${error.message}`);
        }
    }
});

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

// Disable form while waiting for WASM
function disableForm() {
    document.getElementById('calculate-btn').disabled = true;
    document.getElementById('calculate-btn').textContent = 'Loading WASM...';
}

// Enable form when WASM ready
function enableForm() {
    document.getElementById('calculate-btn').disabled = false;
    document.getElementById('calculate-btn').textContent = 'Calculate';
}
