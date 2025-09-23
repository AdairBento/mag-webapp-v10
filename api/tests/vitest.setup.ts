/**
 * Vitest global setup – mock do Prisma para evitar conexão real nos testes.
 * Cobre: client, insurer, insurancePolicy, vehicle, rental, maintenanceOrder, notificationMessage e $transaction.
 */
import { vi } from "vitest";

process.env.NODE_ENV ??= "test";
process.env.DATABASE_URL ??= "postgresql://user:pass@localhost:5432/fake_db";

/** mini "tabela" em memória com API semelhante à do Prisma */
function makeTable(initial: any[]) {
  const store = [...initial];
  const now = () => new Date();
  return {
    findMany: vi.fn(async (args: any = {}) => {
      const take = args?.take ?? store.length;
      // filtro simples por igualdade em where (ignora operadores complexos)
      if (args?.where && typeof args.where === "object") {
        const entries = Object.entries(args.where);
        const filtered = store.filter((row) =>
          entries.every(([k, v]: any) => {
            if (v && typeof v === "object" && "contains" in v) {
              return String(row[k] ?? "").includes(String(v.contains ?? ""));
            }
            if (v && typeof v === "object" && "equals" in v) {
              return row[k] === v.equals;
            }
            return row[k] === v;
          }),
        );
        return filtered.slice(0, take);
      }
      return store.slice(0, take);
    }),
    findUnique: vi.fn(async (args: any) => {
      const id = args?.where?.id ?? args?.where;
      return store.find((x) => x.id === id) ?? null;
    }),
    create: vi.fn(async (args: any) => {
      const data = args?.data ?? {};
      const obj = {
        id: data.id ?? `id_${store.length + 1}`,
        ...data,
        createdAt: data.createdAt ?? now(),
        updatedAt: now(),
      };
      store.push(obj);
      return obj;
    }),
    update: vi.fn(async (args: any) => {
      const id = args?.where?.id ?? args?.where;
      const idx = store.findIndex((x) => x.id === id);
      if (idx < 0) throw new Error("Not found");
      store[idx] = { ...store[idx], ...(args?.data ?? {}), updatedAt: now() };
      return store[idx];
    }),
    delete: vi.fn(async (args: any) => {
      const id = args?.where?.id ?? args?.where;
      const idx = store.findIndex((x) => x.id === id);
      if (idx < 0) throw new Error("Not found");
      const [del] = store.splice(idx, 1);
      return del;
    }),
    count: vi.fn(async () => store.length),
    __store: store, // útil se quiser inspecionar em algum teste
  };
}

// seeds mínimas para todas as rotas tocarem dados sem quebrar
const now = new Date(0);
const clients = makeTable([
  {
    id: "c1",
    name: "Cliente Demo",
    document: "00000000000",
    email: "demo@example.com",
    phone: "0000-0000",
    createdAt: now,
    updatedAt: now,
  },
]);
const insurers = makeTable([
  { id: "ins1", name: "Seguradora Demo", createdAt: now, updatedAt: now },
]);
const policies = makeTable([
  {
    id: "pol1",
    policyNumber: "P-001",
    insurerId: "ins1",
    status: "ACTIVE",
    startDate: now,
    endDate: null,
    createdAt: now,
    updatedAt: now,
  },
]);
const vehicles = makeTable([
  { id: "v1", plate: "ABC-1234", model: "Carro Demo", year: 2020, createdAt: now, updatedAt: now },
]);
const rentals = makeTable([
  {
    id: "r1",
    clientId: "c1",
    vehicleId: "v1",
    status: "OPEN",
    dailyRate: 100,
    startDate: now,
    endDate: null,
    createdAt: now,
    updatedAt: now,
  },
]);
const maint = makeTable([
  {
    id: "m1",
    vehicleId: "v1",
    status: "OPEN",
    description: "Troca de óleo",
    createdAt: now,
    updatedAt: now,
  },
]);
const notifications = makeTable([]);

const txClient = {
  client: clients,
  insurer: insurers,
  insurancePolicy: policies,
  vehicle: vehicles,
  rental: rentals,
  maintenanceOrder: maint,
  notificationMessage: notifications,
};

vi.mock("../src/services/prisma", () => {
  return {
    prisma: {
      ...txClient,
      // transação "fake": roda o callback entregando as mesmas tabelas em memória
      $transaction: vi.fn(async (cb: any) => cb(txClient)),
    },
  };
});

// se quiser limpar contadores/spies entre testes, descomente:
// import { afterEach } from "vitest";
// afterEach(() => vi.clearAllMocks());
