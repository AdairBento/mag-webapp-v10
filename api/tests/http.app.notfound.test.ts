import { it, expect } from 'vitest';
import request from 'supertest';
import * as App from '../src/http/app';

// Suporta export default, named (app) e Fastify (app.server) ou Express (app)
function getServer(mod: any) {
  const appAny = (mod as any)?.default ?? (mod as any)?.app ?? (mod as any);
  return (appAny as any)?.server ?? appAny;
}

it('retorna 404 para rota desconhecida', async () => {
  const server = getServer(App);
  const res = await request(server).get('/__rota_inexistente__');
  expect(res.status).toBe(404);
});
