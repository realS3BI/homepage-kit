import { readFileSync } from 'node:fs'
import { defineConfig } from 'astro/config'

// kit.env is the single place for project settings; the shell scripts read it too.
function readKitEnv() {
  const values = {}
  for (const file of ['kit.env', 'kit.local.env']) {
    let text = ''
    try {
      text = readFileSync(new URL(file, import.meta.url), 'utf8')
    } catch {
      continue
    }
    for (const line of text.split('\n')) {
      const match = line.match(/^([A-Z_]+)=(.*)$/)
      if (match) values[match[1]] = match[2].trim().replace(/^"(.*)"$/, '$1')
    }
  }
  return values
}

const kit = readKitEnv()

export default defineConfig({
  // Canonical URLs, hreflang links and the sitemap are built from this address.
  site: kit.SITE_DOMAIN ? `https://${kit.SITE_DOMAIN}` : 'https://example.invalid',
  trailingSlash: 'always',
  devToolbar: { enabled: false },
  server: {
    // The preview is opened through `tailscale serve`, which sends the tailnet host name.
    allowedHosts: ['.ts.net'],
  },
  vite: {
    server: {
      // `tailscale serve` holds the preview port on the tailnet address. Without this,
      // the dev server treats the port as taken and silently moves to the next one.
      strictPort: true,
      // Poll for file changes. The macOS file-event service can hang after large
      // file operations; the preview would then show old content without any error.
      watch: {
        usePolling: true,
        interval: 500,
        binaryInterval: 1500,
        ignored: ['**/examples/**', '**/.kit/**', '**/dist/**'],
      },
    },
  },
})
