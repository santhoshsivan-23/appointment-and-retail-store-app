import react from '@vitejs/plugin-react'
import net from 'net'
import { defineConfig, type Plugin } from 'vite'

function lanPrinterPlugin(): Plugin {
  const handlePrintRequest = (req: any, res: any, next: any) => {
    if (!req.url?.startsWith('/api/printer/raw')) {
      return next()
    }

    if (req.method !== 'POST') {
      res.writeHead(405, { 'Content-Type': 'application/json' })
      return res.end(JSON.stringify({ success: false, message: 'Method Not Allowed' }))
    }

    const chunks: Buffer[] = []
    req.on('data', (chunk: Buffer) => chunks.push(chunk))
    req.on('end', () => {
      try {
        const bodyStr = Buffer.concat(chunks).toString('utf8')
        const payload = JSON.parse(bodyStr || '{}')
        const ip = (payload.ip_address || '192.168.1.51').trim()
        const port = parseInt(payload.port, 10) || 9100

        let buffer: Buffer
        if (payload.raw_base64) {
          buffer = Buffer.from(payload.raw_base64, 'base64')
        } else if (Array.isArray(payload.raw_bytes)) {
          buffer = Buffer.from(payload.raw_bytes)
        } else {
          res.writeHead(400, { 'Content-Type': 'application/json' })
          return res.end(
            JSON.stringify({
              success: false,
              message: 'Missing raw_base64 or raw_bytes in payload.',
            })
          )
        }

        const socket = new net.Socket()
        let finished = false

        const timeout = setTimeout(() => {
          if (!finished) {
            finished = true
            socket.destroy()
            res.writeHead(504, { 'Content-Type': 'application/json' })
            res.end(
              JSON.stringify({
                success: false,
                message: `Connection timed out. LAN printer at ${ip}:${port} did not answer within 5 seconds.`,
              })
            )
          }
        }, 5000)

        socket.once('error', (err) => {
          if (!finished) {
            finished = true
            clearTimeout(timeout)
            res.writeHead(502, { 'Content-Type': 'application/json' })
            res.end(
              JSON.stringify({
                success: false,
                message: `LAN printer socket error: ${err.message}`,
              })
            )
          }
        })

        socket.connect(port, ip, () => {
          if (!finished) {
            finished = true
            clearTimeout(timeout)
            socket.write(buffer, () => {
              socket.end()
            })
            res.writeHead(200, { 'Content-Type': 'application/json' })
            res.end(
              JSON.stringify({
                success: true,
                message: `Direct print sent successfully to LAN printer at ${ip}:${port}!`,
              })
            )
          }
        })
      } catch (err: any) {
        res.writeHead(500, { 'Content-Type': 'application/json' })
        res.end(JSON.stringify({ success: false, message: err.message || 'Internal error' }))
      }
    })
  }

  return {
    name: 'lan-printer-direct',
    configureServer(server) {
      server.middlewares.use(handlePrintRequest)
    },
    configurePreviewServer(server) {
      server.middlewares.use(handlePrintRequest)
    },
  }
}

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), lanPrinterPlugin()],
})
