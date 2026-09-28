import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Ports come from the worktree's .workspace.env (loaded by bin/ws-run or by
// `set -a; . ./.workspace.env; set +a`). Defaults match workspace 1.
const frontendPort = Number(process.env.FRONTEND_PORT ?? 5173)
const apiPort = Number(process.env.API_PORT ?? 8081)

export default defineConfig({
  plugins: [react()],
  server: {
    host: '127.0.0.1', // never expose on the VM's public interface
    port: frontendPort,
    strictPort: true,
    proxy: {
      '/api': { target: `http://127.0.0.1:${apiPort}`, changeOrigin: true },
    },
  },
  preview: { host: '127.0.0.1', port: frontendPort, strictPort: true },
})
