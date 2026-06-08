# Happy Numbers - GitHub Pages + WASM

Pure browser-based Happy Numbers calculator using WebAssembly and HTMX.

**No backend server required.** Everything runs in the browser.

## 🚀 Quick Start

```bash
# Install dependencies
npm install

# Serve locally
npx http-server public/

# Or Python
python -m http.server 8000 --directory public
```

Visit `http://localhost:8000` (or `http://localhost:3000` with http-server)

## 📦 Architecture

### Frontend Stack
- **HTML/CSS**: Modern, responsive interface
- **HTMX**: Form handling and dynamic updates (no page reload)
- **JavaScript**: Bridge between HTMX and WASM
- **WASM**: WebAssembly calculations (Raku compiled)

### No Backend
- Everything runs **in the browser**
- No server needed
- Deploy to GitHub Pages
- Works offline once loaded

## 📁 File Structure

```
public/
├── index.html          # Main UI
├── app.js              # HTMX ↔ WASM bridge
└── happy_numbers.js    # WASM bindings (JS fallback)

wasm/
├── HappyNumbers.rakumod  # Raku source for WASM
└── build.raku            # WASM compilation script
```

## 🔨 Building WASM

To compile Raku to WebAssembly:

```bash
cd wasm
# Requires: zef install Inline::Wasm
raku build.raku
```

Currently using **JavaScript fallback** for happy number calculations.
Full WASM compilation instructions coming soon.

## 🎯 Features

- ✅ Calculate happy numbers in any base (2-36)
- ✅ Adjust power exponent (1-10)
- ✅ Filter for "pure" happy numbers
- ✅ Interactive hash table
- ✅ Sequence visualization
- ✅ No page reload needed
- ✅ Runs entirely in browser

## 🧮 What's a Happy Number?

A number where repeatedly summing the squares of its digits reaches 1.

**Example: 7 is happy**
```
7 → 7² = 49
49 → 4² + 9² = 97
97 → 9² + 7² = 130
130 → 1² + 3² + 0² = 10
10 → 1² + 0² = 1 ✓
```

## 📚 Resources

- [Happy Number - Wikipedia](https://en.wikipedia.org/wiki/Happy_number)
- [HTMX Documentation](https://htmx.org)
- [Raku Language](https://www.raku.org)
- [WebAssembly Docs](https://webassembly.org)

## 🚢 Deployment

### GitHub Pages
```bash
# Ensure public/ is in docs/ or configure Pages to serve from public/
git push
```

Then enable GitHub Pages in repository settings pointing to `public/` folder.

### Alternative Hosting
- Netlify
- Vercel
- CloudFlare Pages
- Any static hosting

## 🤝 Contributing

Ideas for improvements:
- [ ] Full Raku → WASM compilation pipeline
- [ ] Tree view visualization
- [ ] Export results as CSV/JSON
- [ ] Custom base representations
- [ ] Performance optimizations

## 📄 License

MIT License - See repository for details
