import path from 'node:path'
import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const backendOrigin = env.BACKEND_TARGET || env.VITE_BACKEND_ORIGIN

  return {
    plugins: [react(), tailwindcss()],
    resolve: {
      alias: {
        '@': path.resolve(__dirname, './src'),
      },
    },
    server: {
      proxy: {
        '/api': {
          target: backendOrigin ?? 'http://backend-not-configured.invalid',
          changeOrigin: true,
          configure: () => {
            if (!backendOrigin) {
              throw new Error('Set BACKEND_TARGET or VITE_BACKEND_ORIGIN to the backend server URL.')
            }
          },
        },
      },
    },
  }
})
