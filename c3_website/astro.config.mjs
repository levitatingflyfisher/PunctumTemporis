import { defineConfig } from 'astro/config';

export default defineConfig({
  // Site URL — replace [C3_DOMAIN] before deployment
  site: 'https://[C3_DOMAIN].org',
  output: 'static',
  build: {
    // Cloudflare Pages expects dist/ by default
    outDir: './dist',
  },
});
