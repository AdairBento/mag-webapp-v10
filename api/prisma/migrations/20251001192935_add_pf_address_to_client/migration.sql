/*
  Warnings:

  - A unique constraint covering the columns `[tenantId,cpf]` on the table `Client` will be added. If there are existing duplicate values, this will fail.

*/
-- AlterTable
ALTER TABLE "Client" ADD COLUMN     "cep" VARCHAR(8),
ADD COLUMN     "city" VARCHAR(80),
ADD COLUMN     "complement" VARCHAR(60),
ADD COLUMN     "cpf" VARCHAR(14),
ADD COLUMN     "district" VARCHAR(80),
ADD COLUMN     "number" VARCHAR(20),
ADD COLUMN     "personType" TEXT NOT NULL DEFAULT 'PF',
ADD COLUMN     "state" VARCHAR(2),
ADD COLUMN     "street" VARCHAR(120);

-- CreateIndex
CREATE UNIQUE INDEX "Client_tenantId_cpf_key" ON "Client"("tenantId", "cpf");
