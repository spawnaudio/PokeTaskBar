import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
export default defineConfig({
  base: './',
  plugins: [react(), {
    name: 'local-file-script',
    transformIndexHtml: { order: 'post', handler(html) {
      // WKWebView file URLs cannot fetch ES modules across their opaque origin.
      return html.replace('type="module" crossorigin', 'defer').replaceAll(' crossorigin', '');
    } },
  }],
  build: {
    outDir: '../Sources/PokeTaskBar/Resources/BattleWindow', emptyOutDir: true,
    rollupOptions: { output: { format: 'iife', inlineDynamicImports: true } },
  },
});
