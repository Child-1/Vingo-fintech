import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    allowedHosts: true,   // required for ngrok / external tunnels
    proxy: {
      '/api': {
        target: process.env.VITE_API_URL ?? 'https://vingo-fintech.onrender.com',
        changeOrigin: true,
      },
      '/auth': {
        target: process.env.VITE_API_URL ?? 'https://vingo-fintech.onrender.com',
        changeOrigin: true,
      },
    },
  },
})
