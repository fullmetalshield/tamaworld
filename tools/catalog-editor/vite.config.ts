import { defineConfig, type Plugin } from 'vite';
import react from '@vitejs/plugin-react';
import fs from 'node:fs';
import path from 'node:path';

const DATA_DIR = path.resolve(__dirname, '../../data');
const CATALOGS = ['actions', 'clubs', 'schools', 'jobs'] as const;

// Tiny middleware so the React app can GET/PUT data/*.json directly. Keeps
// us from needing a separate Express process — Vite's dev server is the
// only thing running.
function catalogApi(): Plugin {
  return {
    name: 'tamaworld-catalog-api',
    configureServer(server) {
      server.middlewares.use('/api/catalog', (req, res, next) => {
        const url = req.url ?? '';
        const name = url.replace(/^\/+/, '').split('/')[0].split('?')[0];
        if (!CATALOGS.includes(name as (typeof CATALOGS)[number])) {
          res.statusCode = 404;
          res.end('unknown catalog');
          return;
        }
        const filePath = path.join(DATA_DIR, `${name}.json`);
        if (req.method === 'GET') {
          fs.readFile(filePath, 'utf8', (err, content) => {
            if (err) {
              res.statusCode = 500;
              res.end(String(err));
              return;
            }
            res.setHeader('Content-Type', 'application/json; charset=utf-8');
            res.end(content);
          });
          return;
        }
        if (req.method === 'PUT') {
          let body = '';
          req.on('data', (chunk: Buffer) => {
            body += chunk.toString('utf8');
          });
          req.on('end', () => {
            try {
              const parsed = JSON.parse(body);
              const pretty = JSON.stringify(parsed, null, 2) + '\n';
              fs.writeFile(filePath, pretty, 'utf8', (err) => {
                if (err) {
                  res.statusCode = 500;
                  res.end(String(err));
                  return;
                }
                res.statusCode = 204;
                res.end();
              });
            } catch (e) {
              res.statusCode = 400;
              res.end(String(e));
            }
          });
          return;
        }
        next();
      });
    },
  };
}

export default defineConfig({
  plugins: [react(), catalogApi()],
  server: {
    port: 5179,
    strictPort: false,
  },
});
