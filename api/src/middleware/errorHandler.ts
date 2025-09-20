
import { Request, Response, NextFunction } from 'express';
import { Prisma } from '@prisma/client';
import { ZodError } from 'zod';

export const errorHandler = (error: any, _req: Request, res: Response, _next: NextFunction) => {
  console.error('Error:', error);
  if (error instanceof ZodError) return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: 'Dados inválidos', details: error.errors }});
  if (error instanceof Prisma.PrismaClientKnownRequestError) {
    if (error.code === 'P2002') return res.status(409).json({ error: { code: 'DUPLICATE_ENTRY', message: 'Registro duplicado' }});
    if (error.code === 'P2025') return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Registro não encontrado' }});
  }
  res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: 'Erro interno do servidor' }});
};
