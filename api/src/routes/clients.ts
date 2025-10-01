import { Router } from "express";
import { z } from "zod";
import { prisma } from "../services/prisma";
import { lookupCep } from "../utils/cep";

const router = Router();

// Schemas
const ClientBase = z.object({
  name: z.string().min(2),
  email: z.string().email().optional().or(z.literal("")),
  phone: z.string().optional().or(z.literal("")),
  personType: z.enum(["PF","PJ"]).default("PF"),
  cpf: z.string().optional().or(z.literal("")),
  cep: z.string().optional().or(z.literal("")),
  street: z.string().optional().or(z.literal("")),
  number: z.string().optional().or(z.literal("")),
  complement: z.string().optional().or(z.literal("")),
  district: z.string().optional().or(z.literal("")),
  city: z.string().optional().or(z.literal("")),
  state: z.string().length(2).optional().or(z.literal("")),
  whatsappOptIn: z.boolean().optional(),
});
const ClientCreate = ClientBase.extend({ tenantId: z.string().uuid() });
const ClientUpdate = ClientBase.partial();

// Helpers
function normalizeEmptyToNull<T extends Record<string, any>>(obj: T){
  const out: any = { ...obj };
  for(const k of Object.keys(out)){
    if(typeof out[k] === "string" && out[k].trim() === "") out[k] = null;
  }
  return out as T;
}

// GET /api/clients?q=...
router.get("/", async (req, res, next) => {
  try{
    const q = String(req.query.q || "").trim();
    const where: any = { tenantId: req.headers["x-tenant-id"] as string };
    if(q){
      where.OR = [
        { name:  { contains: q, mode: "insensitive" } },
        { email: { contains: q, mode: "insensitive" } },
        { phone: { contains: q, mode: "insensitive" } },
        { cpf:   { contains: q, mode: "insensitive" } },
      ];
    }
    const rows = await prisma.client.findMany({ where, orderBy:[{ createdAt: "desc" }] });
    res.json(rows);
  }catch(err){ next(err); }
});

// GET by id
router.get("/:id", async (req, res, next) => {
  try{
    const row = await prisma.client.findFirst({
      where: { id: req.params.id, tenantId: req.headers["x-tenant-id"] as string },
    });
    if(!row) return res.status(404).json({ error: "Cliente não encontrado" });
    res.json(row);
  }catch(err){ next(err); }
});

// POST (autocompleta endereço via CEP se faltar)
router.post("/", async (req, res, next) => {
  try{
    const data = ClientCreate.parse(req.body ?? {});
    const tenantId = data.tenantId;

    let addr = normalizeEmptyToNull({
      cep: data.cep, street: data.street, number: data.number, complement: data.complement,
      district: data.district, city: data.city, state: data.state,
    });

    if(addr.cep && (!addr.street || !addr.city || !addr.state)){
      try{
        const via = await lookupCep(addr.cep);
        addr = { ...addr, ...via };
      }catch{}
    }

    const created = await prisma.client.create({
      data: {
        tenantId,
        personType: data.personType,
        cpf: data.cpf ? data.cpf.replace(/\D/g, "") : null,
        name: data.name,
        email: data.email || null,
        phone: data.phone || null,
        whatsappOptIn: data.whatsappOptIn ?? false,
        ...addr,
      },
    });
    res.status(201).json(created);
  }catch(err){ next(err); }
});

// PUT (substitui tudo)
router.put("/:id", async (req, res, next) => {
  try{
    const id = req.params.id;
    const body = ClientBase.parse(req.body ?? {});
    let addr = normalizeEmptyToNull({
      cep: body.cep, street: body.street, number: body.number, complement: body.complement,
      district: body.district, city: body.city, state: body.state,
    });
    if(addr.cep && (!addr.street || !addr.city || !addr.state)){
      try{
        const via = await lookupCep(addr.cep);
        addr = { ...addr, ...via };
      }catch{}
    }

    const updated = await prisma.client.update({
      where: { id },
      data: {
        personType: body.personType ?? "PF",
        cpf: body.cpf ? body.cpf.replace(/\D/g, "") : null,
        name: body.name,
        email: body.email || null,
        phone: body.phone || null,
        whatsappOptIn: body.whatsappOptIn ?? false,
        ...addr,
      },
    });
    res.json(updated);
  }catch(err){ next(err); }
});

// PATCH (parcial)
router.patch("/:id", async (req, res, next) => {
  try{
    const id = req.params.id;
    const body = ClientUpdate.parse(req.body ?? {});
    const data: any = normalizeEmptyToNull(body);
    if(data.cep && (!data.street || !data.city || !data.state)){
      try{
        const via = await lookupCep(String(data.cep));
        Object.assign(data, via);
      }catch{}
    }
    if(data.cpf) data.cpf = String(data.cpf).replace(/\D/g, "");

    const updated = await prisma.client.update({ where: { id }, data });
    res.json(updated);
  }catch(err){ next(err); }
});

// DELETE
router.delete("/:id", async (req, res, next) => {
  try{
    const id = req.params.id;
    await prisma.client.delete({ where: { id } });
    res.status(204).send();
  }catch(err){ next(err); }
});

export default router;
export { router as clientsRoutes };
