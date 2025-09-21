import express from "express";
import cors from "cors";
import { PrismaClient } from "@prisma/client";
import jwt from "jsonwebtoken";
import bcrypt from "bcryptjs";

const app = express();
const prisma = new PrismaClient();

const PORT = Number(process.env.PORT || 3001);
const JWT_SECRET = process.env.JWT_SECRET || "changeme_super_secret_key";

// CORS: defina CORS_ORIGIN no .env (ex.: http://127.0.0.1:3000,http://localhost:3000)
const allowed = (process.env.CORS_ORIGIN || "")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);

app.use(cors({ origin: allowed.length ? allowed : true }));
app.use(express.json());

// -------------------- Auth middleware --------------------
function auth(req: any, res: any, next: any) {
  const h = req.headers?.authorization || "";
  if (!h.startsWith("Bearer ")) {
    return res.status(401).json({ ok: false, error: "Bearer token requerido" });
  }
  try {
    req.auth = jwt.verify(h.slice(7), JWT_SECRET);
    next();
  } catch (_e: any) {
    return res.status(401).json({ ok: false, error: "Token inválido" });
  }
}

// -------------------- HEALTH --------------------
app.get("/healthz", async (_req, res) => {
  try {
    const rows: any = await prisma.$queryRaw`SELECT NOW() as now`;
    res.json({
      ok: true,
      db: "up",
      now: rows?.[0]?.now ?? null,
      env: { node: process.version, port: PORT, node_env: process.env.NODE_ENV || null },
    });
  } catch (e: any) {
    res.status(500).json({ ok: false, db: "down", error: e?.message || String(e) });
  }
});

// -------------------- AUTH --------------------
app.post("/auth/login", async (req, res) => {
  try {
    const { email, password } = req.body ?? {};
    if (!email || !password) {
      return res.status(400).json({ ok: false, error: "Email e password obrigatórios" });
    }

    const user = await prisma.user.findUnique({
      where: { email },
      include: { tenants: { include: { tenant: true } } },
    });

    if (!user?.password || !(await bcrypt.compare(String(password), String(user.password)))) {
      return res.status(401).json({ ok: false, error: "Credenciais inválidas" });
    }

    const tenantId = user.tenants?.[0]?.tenantId;
    const role = user.tenants?.[0]?.role;

    const token = jwt.sign(
      { sub: user.id, email: user.email, tenantId, role },
      JWT_SECRET,
      { expiresIn: "12h" },
    );

    res.json({
      ok: true,
      token,
      user: { id: user.id, email: user.email, name: user.name },
      tenant: user.tenants?.[0]?.tenant,
      role,
    });
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

app.get("/me", auth, (req: any, res) => res.json({ ok: true, auth: req.auth }));

// -------------------- CLIENTES --------------------
app.get("/api/clientes", auth, async (req: any, res) => {
  try {
    const clientes = await prisma.cliente.findMany({
      where: { tenantId: req.auth.tenantId, ativo: true },
      orderBy: { nome: "asc" },
    });
    res.json(clientes);
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

app.post("/api/clientes", auth, async (req: any, res) => {
  try {
    const cliente = await prisma.cliente.create({
      data: { ...req.body, tenantId: req.auth.tenantId },
    });
    res.json({ ok: true, cliente });
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

app.get("/api/clientes/:id", auth, async (req: any, res) => {
  try {
    const cliente = await prisma.cliente.findFirst({
      where: { id: req.params.id, tenantId: req.auth.tenantId },
      include: {
        locacoes: { include: { equipamento: true } },
        multas: true,
        sinistros: true,
        financeiro: true,
      },
    });
    if (!cliente) return res.status(404).json({ ok: false, error: "Cliente não encontrado" });
    res.json(cliente);
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

app.put("/api/clientes/:id", auth, async (req: any, res) => {
  try {
    await prisma.cliente.updateMany({
      where: { id: req.params.id, tenantId: req.auth.tenantId },
      data: req.body,
    });
    res.json({ ok: true });
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

// -------------------- EQUIPAMENTOS --------------------
app.get("/api/equipamentos", auth, async (req: any, res) => {
  try {
    const { status } = req.query;
    const where: any = { tenantId: req.auth.tenantId, ativo: true };
    if (status) where.status = status;
    const equipamentos = await prisma.equipamento.findMany({ where, orderBy: { codigo: "asc" } });
    res.json(equipamentos);
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

app.post("/api/equipamentos", auth, async (req: any, res) => {
  try {
    const equipamento = await prisma.equipamento.create({
      data: { ...req.body, tenantId: req.auth.tenantId },
    });
    res.json({ ok: true, equipamento });
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

app.get("/api/equipamentos/:id", auth, async (req: any, res) => {
  try {
    const equipamento = await prisma.equipamento.findFirst({
      where: { id: req.params.id, tenantId: req.auth.tenantId },
      include: {
        locacoes: { include: { cliente: true } },
        manutencoes: true,
        sinistros: true,
        seguros: true,
      },
    });
    if (!equipamento) return res.status(404).json({ ok: false, error: "Equipamento não encontrado" });
    res.json(equipamento);
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

// -------------------- LOCAÇÕES --------------------
app.get("/api/locacoes", auth, async (req: any, res) => {
  try {
    const { status } = req.query;
    const where: any = { tenantId: req.auth.tenantId };
    if (status) where.status = status;

    const locacoes = await prisma.locacao.findMany({
      where,
      include: {
        cliente: { select: { id: true, nome: true, razaoSocial: true } },
        equipamento: { select: { id: true, codigo: true, tipo: true, marca: true, modelo: true } },
      },
      orderBy: { createdAt: "desc" },
    });
    res.json(locacoes);
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

app.post("/api/locacoes", auth, async (req: any, res) => {
  try {
    const equipamento = await prisma.equipamento.findFirst({
      where: { id: req.body.equipamentoId, tenantId: req.auth.tenantId, status: "DISPONIVEL" },
    });
    if (!equipamento) return res.status(400).json({ ok: false, error: "Equipamento não disponível" });

    const count = await prisma.locacao.count({ where: { tenantId: req.auth.tenantId } });
    const numero = `LOC${String(count + 1).padStart(6, "0")}`;

    const locacao = await prisma.$transaction(async (tx) => {
      const nova = await tx.locacao.create({
        data: { ...req.body, tenantId: req.auth.tenantId, numero },
      });
      await tx.equipamento.update({
        where: { id: req.body.equipamentoId },
        data: { status: "LOCADO" },
      });
      return nova;
    });

    res.json({ ok: true, locacao });
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

app.put("/api/locacoes/:id/finalizar", auth, async (req: any, res) => {
  try {
    const { kmFinal, horasFinal, condicoes } = req.body;

    await prisma.$transaction(async (tx) => {
      await tx.locacao.updateMany({
        where: { id: req.params.id, tenantId: req.auth.tenantId },
        data: { status: "FINALIZADA", dataRetorno: new Date(), kmFinal, horasFinal, condicoes },
      });

      const loc = await tx.locacao.findFirst({
        where: { id: req.params.id, tenantId: req.auth.tenantId },
      });

      if (loc) {
        await tx.equipamento.update({
          where: { id: loc.equipamentoId },
          data: { status: "DISPONIVEL", kmAtual: kmFinal, horasUso: horasFinal },
        });
      }
    });

    res.json({ ok: true });
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

// -------------------- MANUTENÇÕES --------------------
app.get("/api/manutencoes", auth, async (req: any, res) => {
  try {
    const manutencoes = await prisma.manutencao.findMany({
      where: { tenantId: req.auth.tenantId },
      include: { equipamento: { select: { codigo: true, tipo: true, marca: true, modelo: true } } },
      orderBy: { dataAgendada: "desc" },
    });
    res.json(manutencoes);
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

app.post("/api/manutencoes", auth, async (req: any, res) => {
  try {
    const count = await prisma.manutencao.count({ where: { tenantId: req.auth.tenantId } });
    const numero = `MAN${String(count + 1).padStart(6, "0")}`;

    const manutencao = await prisma.manutencao.create({
      data: { ...req.body, tenantId: req.auth.tenantId, numero },
    });

    if (req.body.tipo === "CORRETIVA" || req.body.tipo === "EMERGENCIAL") {
      await prisma.equipamento.updateMany({
        where: { id: req.body.equipamentoId, tenantId: req.auth.tenantId },
        data: { status: "MANUTENCAO" },
      });
    }

    res.json({ ok: true, manutencao });
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

// -------------------- MULTAS --------------------
app.get("/api/multas", auth, async (req: any, res) => {
  try {
    const { status } = req.query;
    const where: any = { tenantId: req.auth.tenantId };
    if (status) where.status = status;

    const multas = await prisma.multa.findMany({
      where,
      include: {
        cliente: { select: { nome: true, razaoSocial: true } },
        locacao: { select: { numero: true, equipamento: { select: { codigo: true } } } },
      },
      orderBy: { dataInfracao: "desc" },
    });
    res.json(multas);
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

app.post("/api/multas", auth, async (req: any, res) => {
  try {
    const count = await prisma.multa.count({ where: { tenantId: req.auth.tenantId } });
    const numero = `MUL${String(count + 1).padStart(6, "0")}`;
    const multa = await prisma.multa.create({ data: { ...req.body, tenantId: req.auth.tenantId, numero } });
    res.json({ ok: true, multa });
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

// -------------------- SINISTROS --------------------
app.get("/api/sinistros", auth, async (req: any, res) => {
  try {
    const sinistros = await prisma.sinistro.findMany({
      where: { tenantId: req.auth.tenantId },
      include: {
        cliente: { select: { nome: true, razaoSocial: true } },
        equipamento: { select: { codigo: true, tipo: true, marca: true, modelo: true } },
        locacao: { select: { numero: true } },
      },
      orderBy: { dataOcorrencia: "desc" },
    });
    res.json(sinistros);
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

app.post("/api/sinistros", auth, async (req: any, res) => {
  try {
    const count = await prisma.sinistro.count({ where: { tenantId: req.auth.tenantId } });
    const numero = `SIN${String(count + 1).padStart(6, "0")}`;
    const sinistro = await prisma.sinistro.create({ data: { ...req.body, tenantId: req.auth.tenantId, numero } });

    if (req.body.gravidade === "PERDA_TOTAL") {
      await prisma.equipamento.updateMany({
        where: { id: req.body.equipamentoId, tenantId: req.auth.tenantId },
        data: { status: "INDISPONIVEL" },
      });
    }

    res.json({ ok: true, sinistro });
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

// -------------------- SEGUROS --------------------
app.get("/api/seguros", auth, async (req: any, res) => {
  try {
    const { status } = req.query;
    const where: any = { tenantId: req.auth.tenantId };
    if (status) where.status = status;

    const seguros = await prisma.seguro.findMany({
      where,
      include: { equipamento: { select: { codigo: true, tipo: true, marca: true, modelo: true, placa: true } } },
      orderBy: { dataFim: "asc" },
    });
    res.json(seguros);
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

app.post("/api/seguros", auth, async (req: any, res) => {
  try {
    const count = await prisma.seguro.count({ where: { tenantId: req.auth.tenantId } });
    const numero = `SEG${String(count + 1).padStart(6, "0")}`;
    const seguro = await prisma.seguro.create({ data: { ...req.body, tenantId: req.auth.tenantId, numero } });
    res.json({ ok: true, seguro });
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

app.get("/api/seguros/vencendo", auth, async (req: any, res) => {
  try {
    const proximoMes = new Date();
    proximoMes.setMonth(proximoMes.getMonth() + 1);

    const seguros = await prisma.seguro.findMany({
      where: { tenantId: req.auth.tenantId, status: "ATIVO", dataFim: { lte: proximoMes } },
      include: { equipamento: { select: { codigo: true, tipo: true, placa: true } } },
      orderBy: { dataFim: "asc" },
    });
    res.json(seguros);
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

// -------------------- FINANCEIRO --------------------
app.get("/api/financeiro", auth, async (req: any, res) => {
  try {
    const { tipo, status, dataInicio, dataFim } = req.query;
    const where: any = { tenantId: req.auth.tenantId };

    if (tipo) where.tipo = tipo;
    if (status) where.status = status;
    if (dataInicio || dataFim) {
      where.dataVencimento = {};
      if (dataInicio) where.dataVencimento.gte = new Date(dataInicio as string);
      if (dataFim) where.dataVencimento.lte = new Date(dataFim as string);
    }

    const financeiro = await prisma.financeiro.findMany({
      where,
      include: { cliente: { select: { nome: true, razaoSocial: true } }, locacao: { select: { numero: true } } },
      orderBy: { dataVencimento: "asc" },
    });
    res.json(financeiro);
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

app.post("/api/financeiro", auth, async (req: any, res) => {
  try {
    const count = await prisma.financeiro.count({ where: { tenantId: req.auth.tenantId } });
    const numero = `FIN${String(count + 1).padStart(6, "0")}`;
    const financeiro = await prisma.financeiro.create({ data: { ...req.body, tenantId: req.auth.tenantId, numero } });
    res.json({ ok: true, financeiro });
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

app.put("/api/financeiro/:id/pagar", auth, async (req: any, res) => {
  try {
    const { formaPagamento, dataPagamento, valorPago } = req.body;

    await prisma.financeiro.updateMany({
      where: { id: req.params.id, tenantId: req.auth.tenantId },
      data: {
        status: "PAGO",
        dataPagamento: dataPagamento ? new Date(dataPagamento) : new Date(),
        formaPagamento,
        valorLiquido: valorPago || undefined,
      },
    });

    res.json({ ok: true });
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

// -------------------- COMUNICAÇÕES --------------------
app.get("/api/comunicacoes", auth, async (req: any, res) => {
  try {
    const comunicacoes = await prisma.comunicacao.findMany({
      where: { tenantId: req.auth.tenantId },
      include: { cliente: { select: { nome: true, razaoSocial: true, whatsapp: true, email: true } } },
      orderBy: { dataEnvio: "desc" },
    });
    res.json(comunicacoes);
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

app.post("/api/comunicacoes", auth, async (req: any, res) => {
  try {
    const comunicacao = await prisma.comunicacao.create({
      data: { ...req.body, tenantId: req.auth.tenantId, dataEnvio: new Date(), tentativas: 1 },
    });

    // simula envio async
    setTimeout(async () => {
      await prisma.comunicacao.update({
        where: { id: comunicacao.id },
        data: { status: "ENVIADO", dataEntrega: new Date() },
      });
    }, 2000);

    res.json({ ok: true, comunicacao });
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

// -------------------- RELATÓRIOS --------------------
app.get("/api/relatorios/dashboard", auth, async (req: any, res) => {
  try {
    const { tenantId } = req.auth;

    const [
      totalClientes,
      totalEquipamentos,
      locacoesAtivas,
      receitasMes,
      multasPendentes,
      sinistrosAbertos,
      manutencoesPendentes,
      segurosVencendo,
    ] = await Promise.all([
      prisma.cliente.count({ where: { tenantId, ativo: true } }),
      prisma.equipamento.count({ where: { tenantId, ativo: true } }),
      prisma.locacao.count({ where: { tenantId, status: "ATIVA" } }),
      prisma.financeiro.aggregate({
        where: {
          tenantId,
          tipo: "RECEITA_LOCACAO",
          dataVencimento: {
            gte: new Date(new Date().getFullYear(), new Date().getMonth(), 1),
            lt: new Date(new Date().getFullYear(), new Date().getMonth() + 1, 1),
          },
        },
        _sum: { valorLiquido: true },
      }),
      prisma.multa.count({ where: { tenantId, status: "PENDENTE" } }),
      prisma.sinistro.count({ where: { tenantId, status: "ABERTO" } }),
      prisma.manutencao.count({ where: { tenantId, status: { in: ["AGENDADA", "INICIADA"] } } }),
      prisma.seguro.count({
        where: { tenantId, status: "ATIVO", dataFim: { lte: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) } },
      }),
    ]);

    res.json({
      totalClientes,
      totalEquipamentos,
      locacoesAtivas,
      receitasMes: receitasMes._sum.valorLiquido || 0,
      multasPendentes,
      sinistrosAbertos,
      manutencoesPendentes,
      segurosVencendo,
    });
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

// -------------------- WHATSAPP (simulado) --------------------
app.post("/api/whatsapp/cobranca", auth, async (req: any, res) => {
  try {
    const vencidos = await prisma.financeiro.findMany({
      where: { tenantId: req.auth.tenantId, status: "VENCIDO", dataVencimento: { lt: new Date() } },
      include: { cliente: { select: { nome: true, whatsapp: true } } },
    });

    const envios: any[] = [];
    for (const item of vencidos) {
      if (item.cliente.whatsapp) {
        const mensagem = `Olá ${item.cliente.nome}!

Você possui uma pendência no valor de R$ ${Number(item.valorLiquido ?? item.valor).toFixed(2)} com vencimento em ${new Date(item.dataVencimento).toLocaleDateString()}.

Para quitação, entre em contato conosco.

Atenciosamente,
Equipe MAG`;

        const c = await prisma.comunicacao.create({
          data: {
            tenantId: req.auth.tenantId,
            clienteId: item.clienteId,
            tipo: "COBRANCA",
            canal: "WHATSAPP",
            assunto: "Cobrança - Pendência Financeira",
            mensagem,
            destinatario: item.cliente.whatsapp,
            dataEnvio: new Date(),
            automatico: true,
            template: "cobranca_vencido",
          },
        });
        envios.push(c);
      }
    }
    res.json({ ok: true, envios: envios.length, comunicacoes: envios });
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

app.post("/api/whatsapp/lembrete", auth, async (req: any, res) => {
  try {
    const limite = new Date();
    limite.setDate(limite.getDate() + 3);

    const vencendo = await prisma.financeiro.findMany({
      where: { tenantId: req.auth.tenantId, status: "PENDENTE", dataVencimento: { gte: new Date(), lte: limite } },
      include: { cliente: { select: { nome: true, whatsapp: true } } },
    });

    const envios: any[] = [];
    for (const item of vencendo) {
      if (item.cliente.whatsapp) {
        const mensagem = `Olá ${item.cliente.nome}!

Lembramos que você possui uma pendência no valor de R$ ${Number(item.valorLiquido ?? item.valor).toFixed(2)} com vencimento em ${new Date(item.dataVencimento).toLocaleDateString()}.

Para evitar juros e multa, realize o pagamento até a data de vencimento.

Atenciosamente,
Equipe MAG`;

        const c = await prisma.comunicacao.create({
          data: {
            tenantId: req.auth.tenantId,
            clienteId: item.clienteId,
            tipo: "LEMBRETE",
            canal: "WHATSAPP",
            assunto: "Lembrete - Vencimento Próximo",
            mensagem,
            destinatario: item.cliente.whatsapp,
            dataEnvio: new Date(),
            automatico: true,
            template: "lembrete_vencimento",
          },
        });
        envios.push(c);
      }
    }
    res.json({ ok: true, envios: envios.length, comunicacoes: envios });
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

// -------------------- DEBUG --------------------
app.get("/debug/routes", (_req, res) => {
  const routes: Array<{ methods: string; path: string }> = [];
  // @ts-ignore
  app._router?.stack?.forEach((layer: any) => {
    if (layer?.route?.path) {
      const methods = Object.keys(layer.route.methods || {})
        .map((m) => m.toUpperCase())
        .join(",");
      routes.push({ methods, path: layer.route.path });
    }
  });
  res.json(routes);
});

// 404 & erro
app.use((_req, res) => res.status(404).json({ ok: false, error: "not_found" }));
app.use((err: any, _req: any, res: any, _next: any) => {
  console.error(err);
  res.status(500).json({ ok: false, error: "internal_error" });
});

app.listen(PORT, () => console.log(`Sistema MAG v10 API rodando em http://127.0.0.1:${PORT}`));
