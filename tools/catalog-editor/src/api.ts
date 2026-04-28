import type { CatalogName } from './types';

const BASE = '/api/catalog';

export async function loadCatalog<T>(name: CatalogName): Promise<T> {
  const res = await fetch(`${BASE}/${name}`);
  if (!res.ok) throw new Error(`failed to load ${name}: ${res.status}`);
  return res.json();
}

export async function saveCatalog(name: CatalogName, data: unknown): Promise<void> {
  const res = await fetch(`${BASE}/${name}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`failed to save ${name}: ${res.status} ${text}`);
  }
}
