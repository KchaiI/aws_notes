import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    proxy: {
      '/api': {
        target: 'https://d305mjm7qp5shx.cloudfront.net',
        changeOrigin: true,
        secure: true,
      },
    },
  },
})
