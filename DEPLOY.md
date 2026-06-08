# Deployment Guide

## Quick Start - Deploy to GitHub Pages

### Option 1: Automatic Deployment (Recommended)

1. **Enable GitHub Pages:**
   - Go to repository Settings → Pages
   - Under "Build and deployment" select:
     - Source: **Deploy from a branch**
     - Branch: **main** / **/ (root)**
   - Click Save

2. **Push code to main:**
   ```bash
   git add .
   git commit -m "Deploy happy numbers calculator"
   git push origin main
   ```

3. **GitHub Actions will automatically:**
   - Run `.github/workflows/deploy.yml`
   - Deploy `public/` folder to GitHub Pages
   - Site available at: `https://azarmadr.github.io/happy-numbers`

### Option 2: Compile WASM First (Better Performance)

Before deploying, compile Raku to WebAssembly for production:

```bash
# Install Raku WASM tooling
zef install Inline::Wasm

# Compile to WASM
raku --target=wasm wasm/HappyNumbers.rakumod -o public/happy_numbers_bg.wasm

# This generates:
# - public/happy_numbers_bg.wasm (binary module)
# - public/happy_numbers.js (bindings)

# Push compiled WASM
git add public/
git commit -m "Add compiled WASM module"
git push origin main
```

## Current Status

- ✅ HTML interface: `public/index.html`
- ✅ JavaScript bridge: `public/app.js`
- ⚠️ WASM module: Needs compilation
- ✅ Deployment config: `.github/workflows/deploy.yml`

## Local Testing

### Option A: With Python
```bash
cd public
python -m http.server 8000
# Visit http://localhost:8000
```

### Option B: With Node http-server
```bash
npx http-server public -p 8000
# Visit http://localhost:8000
```

### Option C: With Raku
```bash
cd public
raku -e 'use Cro::HTTP::Server; my $app = route { static "." }; Cro::HTTP::Server.new(host => "localhost", port => 8000, application => $app).start; react { whenever signal(SIGINT) { exit } }'
```

## Troubleshooting

### "WASM module not compiled"
- The app requires compiled WASM
- Until compiled, you'll see: "Failed to load WebAssembly module"
- See "Option 2: Compile WASM First" above

### GitHub Pages not updating
- Clear browser cache (Ctrl+Shift+Delete or Cmd+Shift+Delete)
- Check Actions tab to see if deployment succeeded
- Verify Settings → Pages shows correct source

### CORS issues locally
- Use `http-server` or Python's `http.server` (not `file://`)
- WASM modules require HTTP context

## Next Steps

1. Compile Raku → WASM
2. Push to main branch
3. Enable GitHub Pages in settings
4. Visit `https://azarmadr.github.io/happy-numbers`

---

**Questions?** Check `.github/workflows/` for automation details.
