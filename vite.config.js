import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig(({ mode }) => ({
  plugins: [react()],
  // The public site uses a custom domain, so browser assets must resolve from the domain root.
  base: mode === 'android' || mode === 'ios' ? './' : '/',
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
}));
