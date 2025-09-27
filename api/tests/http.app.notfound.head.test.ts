import { it, expect } from 'vitest';
import request from 'supertest';
import * as App from '../src/http/app';

function getServer(mod:any){
  const a = (mod as any)?.default ?? (mod as any)?.app ?? (mod as any);
  return (a as any)?.server ?? a;
}

it('HEAD desconhecida retorna 404/405', async () => {
  const server = getServer(App);
  const res = await request(server).head('/__rota_inexistente_head__');
  expect([404, 405]).toContain(res.status);
});
