import { fileURLToPath, URL } from 'node:url'
import vue from '@vitejs/plugin-vue'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  server: {
    allowedHosts: true,
    proxy: Object.fromEntries(['/auth','/rest','/ai','/storage','/channels','/mcp','/cv','/ppt'].map(route=>[route,{target:'http://127.0.0.1:8000',changeOrigin:true}])),
  },
  preview: {
    allowedHosts: true,
    proxy: {
      '/auth': { target: 'http://127.0.0.1:8000', changeOrigin: true, secure: false },
      '/rest': { target: 'http://127.0.0.1:8000', changeOrigin: true, secure: false },
      '/ai': { target: 'http://127.0.0.1:8000', changeOrigin: true, secure: false },
      '/storage': { target: 'http://127.0.0.1:8000', changeOrigin: true, secure: false },
      '/channels': { target: 'http://127.0.0.1:8000', changeOrigin: true, secure: false },
      '/mcp': { target: 'http://127.0.0.1:8000', changeOrigin: true, secure: false },
      '/cv': { target: 'http://127.0.0.1:8000', changeOrigin: true, secure: false },
      '/ppt': { target: 'http://127.0.0.1:8000', changeOrigin: true, secure: false },
    },
  },
})
