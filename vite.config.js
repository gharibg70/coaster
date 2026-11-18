import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  // Relative asset paths work at the custom-domain root and under the GitHub Pages project path.
  base: './',
  build: {
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes('/node_modules/leaflet/')) return 'leaflet';
          if (id.includes('/node_modules/@supabase/')) return 'supabase';
          if (id.includes('/node_modules/react')) return 'react-vendor';
        },
      },
    },
  },
});
