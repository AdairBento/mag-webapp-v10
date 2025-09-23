-- CreateEnum
CREATE TYPE "AssetType" AS ENUM ('vehicle', 'equipment', 'space', 'other');

-- CreateEnum
CREATE TYPE "AssetStatus" AS ENUM ('available', 'rented', 'maintenance');

-- CreateEnum
CREATE TYPE "ContractStatus" AS ENUM ('open', 'closed');

-- CreateEnum
CREATE TYPE "FinanceType" AS ENUM ('payable', 'receivable');

-- CreateEnum
CREATE TYPE "FinanceStatus" AS ENUM ('pending', 'paid', 'canceled');

-- CreateEnum
CREATE TYPE "MaintenanceType" AS ENUM ('preventive', 'corrective');

-- CreateEnum
CREATE TYPE "MaintenanceStatus" AS ENUM ('open', 'finished', 'canceled');

-- CreateEnum
CREATE TYPE "Role" AS ENUM ('admin', 'manager', 'operator');

-- CreateEnum
CREATE TYPE "NotificationChannel" AS ENUM ('whatsapp', 'email', 'sms');

-- CreateEnum
CREATE TYPE "NotificationKind" AS ENUM ('payment_overdue', 'contract_created', 'contract_due_today', 'custom', 'insurance_renewal', 'claim_status_changed');

-- CreateEnum
CREATE TYPE "NotificationStatus" AS ENUM ('queued', 'sent', 'delivered', 'read', 'failed');

-- CreateEnum
CREATE TYPE "IncidentType" AS ENUM ('fine', 'accident', 'theft', 'damage', 'other');

-- CreateEnum
CREATE TYPE "IncidentStatus" AS ENUM ('open', 'settled', 'canceled');

-- CreateEnum
CREATE TYPE "InsurerType" AS ENUM ('bank', 'association', 'insurer');

-- CreateEnum
CREATE TYPE "PolicyStatus" AS ENUM ('active', 'expired', 'canceled');

-- CreateEnum
CREATE TYPE "PremiumPeriodicity" AS ENUM ('monthly', 'quarterly', 'yearly', 'single');

-- CreateEnum
CREATE TYPE "ClaimStatus" AS ENUM ('draft', 'submitted', 'in_analysis', 'approved', 'denied', 'paid', 'closed');

-- CreateTable
CREATE TABLE "Tenant" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "domain" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Tenant_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "User" (
    "id" UUID NOT NULL,
    "email" TEXT NOT NULL,
    "name" TEXT,
    "password" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "UserTenant" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "tenantId" UUID NOT NULL,
    "role" "Role" NOT NULL,

    CONSTRAINT "UserTenant_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RefreshToken" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "token" TEXT NOT NULL,
    "revoked" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "RefreshToken_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Client" (
    "id" UUID NOT NULL,
    "tenantId" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "email" TEXT,
    "phone" TEXT,
    "document" TEXT,
    "whatsappOptIn" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Client_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Vehicle" (
    "id" UUID NOT NULL,
    "tenantId" UUID NOT NULL,
    "plate" TEXT NOT NULL,
    "brand" TEXT NOT NULL,
    "model" TEXT NOT NULL,
    "year" INTEGER NOT NULL,
    "color" TEXT NOT NULL DEFAULT 'Prata',
    "fuelType" TEXT NOT NULL DEFAULT 'Flex',
    "category" TEXT NOT NULL DEFAULT 'Hatch',
    "type" "AssetType" NOT NULL DEFAULT 'vehicle',
    "status" "AssetStatus" NOT NULL DEFAULT 'available',
    "dailyRate" DECIMAL(10,2) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Vehicle_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Rental" (
    "id" UUID NOT NULL,
    "tenantId" UUID NOT NULL,
    "clientId" UUID NOT NULL,
    "vehicleId" UUID NOT NULL,
    "startDate" TIMESTAMP(3) NOT NULL,
    "endDate" TIMESTAMP(3) NOT NULL,
    "status" "ContractStatus" NOT NULL DEFAULT 'open',
    "dailyRate" DECIMAL(10,2) NOT NULL,
    "finalAmount" DECIMAL(12,2),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Rental_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FinanceEntry" (
    "id" UUID NOT NULL,
    "tenantId" UUID NOT NULL,
    "type" "FinanceType" NOT NULL,
    "status" "FinanceStatus" NOT NULL DEFAULT 'pending',
    "amount" DECIMAL(12,2) NOT NULL,
    "dueDate" TIMESTAMP(3) NOT NULL,
    "description" TEXT,
    "originType" TEXT,
    "originId" UUID,
    "splitPercent" DECIMAL(5,2),
    "amountPaid" DECIMAL(12,2),
    "paidAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FinanceEntry_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MaintenanceOrder" (
    "id" UUID NOT NULL,
    "tenantId" UUID NOT NULL,
    "assetId" UUID NOT NULL,
    "type" "MaintenanceType" NOT NULL,
    "status" "MaintenanceStatus" NOT NULL DEFAULT 'open',
    "openedAt" TIMESTAMP(3) NOT NULL,
    "finishedAt" TIMESTAMP(3),
    "totalCost" DECIMAL(12,2),
    "description" TEXT NOT NULL,

    CONSTRAINT "MaintenanceOrder_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "NotificationTemplate" (
    "id" UUID NOT NULL,
    "tenantId" UUID NOT NULL,
    "channel" "NotificationChannel" NOT NULL,
    "kind" "NotificationKind" NOT NULL,
    "name" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "NotificationTemplate_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "NotificationMessage" (
    "id" UUID NOT NULL,
    "tenantId" UUID NOT NULL,
    "clientId" UUID,
    "rentalId" UUID,
    "financeEntryId" UUID,
    "channel" "NotificationChannel" NOT NULL,
    "kind" "NotificationKind" NOT NULL,
    "status" "NotificationStatus" NOT NULL DEFAULT 'queued',
    "recipient" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "externalId" TEXT,
    "error" TEXT,
    "sentAt" TIMESTAMP(3),
    "deliveredAt" TIMESTAMP(3),
    "readAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "NotificationMessage_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Incident" (
    "id" UUID NOT NULL,
    "tenantId" UUID NOT NULL,
    "assetId" UUID NOT NULL,
    "rentalId" UUID,
    "type" "IncidentType" NOT NULL,
    "status" "IncidentStatus" NOT NULL DEFAULT 'open',
    "occurredAt" TIMESTAMP(3) NOT NULL,
    "description" TEXT,
    "amount" DECIMAL(12,2),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Incident_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Insurer" (
    "id" UUID NOT NULL,
    "tenantId" UUID NOT NULL,
    "type" "InsurerType" NOT NULL,
    "name" TEXT NOT NULL,
    "document" TEXT,
    "contact" TEXT,
    "phone" TEXT,
    "email" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Insurer_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "InsurancePolicy" (
    "id" UUID NOT NULL,
    "tenantId" UUID NOT NULL,
    "assetId" UUID NOT NULL,
    "insurerId" UUID NOT NULL,
    "number" TEXT NOT NULL,
    "status" "PolicyStatus" NOT NULL DEFAULT 'active',
    "periodicity" "PremiumPeriodicity" NOT NULL,
    "premiumAmount" DECIMAL(12,2) NOT NULL,
    "coverageStart" TIMESTAMP(3) NOT NULL,
    "coverageEnd" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "InsurancePolicy_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Claim" (
    "id" UUID NOT NULL,
    "tenantId" UUID NOT NULL,
    "policyId" UUID NOT NULL,
    "incidentId" UUID,
    "status" "ClaimStatus" NOT NULL DEFAULT 'draft',
    "openedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "closedAt" TIMESTAMP(3),
    "description" TEXT,
    "claimedValue" DECIMAL(12,2),
    "approvedValue" DECIMAL(12,2),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Claim_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Partner" (
    "id" UUID NOT NULL,
    "tenantId" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "doc" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Partner_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Ownership" (
    "id" UUID NOT NULL,
    "assetId" UUID NOT NULL,
    "partnerId" UUID NOT NULL,
    "revenueShare" DECIMAL(5,2) NOT NULL,

    CONSTRAINT "Ownership_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TenantSettings" (
    "id" UUID NOT NULL,
    "tenantId" UUID NOT NULL,
    "pixKey" TEXT,
    "whatsappPhoneNumberId" TEXT,
    "whatsappAccessToken" TEXT,
    "notificationActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TenantSettings_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE INDEX "UserTenant_tenantId_role_idx" ON "UserTenant"("tenantId", "role");

-- CreateIndex
CREATE UNIQUE INDEX "UserTenant_userId_tenantId_key" ON "UserTenant"("userId", "tenantId");

-- CreateIndex
CREATE UNIQUE INDEX "RefreshToken_token_key" ON "RefreshToken"("token");

-- CreateIndex
CREATE INDEX "RefreshToken_userId_revoked_idx" ON "RefreshToken"("userId", "revoked");

-- CreateIndex
CREATE INDEX "Client_tenantId_name_idx" ON "Client"("tenantId", "name");

-- CreateIndex
CREATE INDEX "Vehicle_tenantId_type_status_idx" ON "Vehicle"("tenantId", "type", "status");

-- CreateIndex
CREATE UNIQUE INDEX "Vehicle_tenantId_plate_key" ON "Vehicle"("tenantId", "plate");

-- CreateIndex
CREATE INDEX "Rental_tenantId_status_idx" ON "Rental"("tenantId", "status");

-- CreateIndex
CREATE INDEX "Rental_tenantId_vehicleId_status_idx" ON "Rental"("tenantId", "vehicleId", "status");

-- CreateIndex
CREATE INDEX "FinanceEntry_tenantId_status_type_idx" ON "FinanceEntry"("tenantId", "status", "type");

-- CreateIndex
CREATE INDEX "FinanceEntry_tenantId_dueDate_idx" ON "FinanceEntry"("tenantId", "dueDate");

-- CreateIndex
CREATE INDEX "MaintenanceOrder_tenantId_status_type_idx" ON "MaintenanceOrder"("tenantId", "status", "type");

-- CreateIndex
CREATE INDEX "NotificationTemplate_tenantId_active_idx" ON "NotificationTemplate"("tenantId", "active");

-- CreateIndex
CREATE UNIQUE INDEX "NotificationTemplate_tenantId_channel_kind_name_key" ON "NotificationTemplate"("tenantId", "channel", "kind", "name");

-- CreateIndex
CREATE INDEX "NotificationMessage_tenantId_status_channel_kind_idx" ON "NotificationMessage"("tenantId", "status", "channel", "kind");

-- CreateIndex
CREATE INDEX "NotificationMessage_tenantId_createdAt_idx" ON "NotificationMessage"("tenantId", "createdAt");

-- CreateIndex
CREATE INDEX "Incident_tenantId_status_type_idx" ON "Incident"("tenantId", "status", "type");

-- CreateIndex
CREATE INDEX "Insurer_tenantId_type_name_idx" ON "Insurer"("tenantId", "type", "name");

-- CreateIndex
CREATE INDEX "InsurancePolicy_tenantId_status_idx" ON "InsurancePolicy"("tenantId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "InsurancePolicy_tenantId_number_key" ON "InsurancePolicy"("tenantId", "number");

-- CreateIndex
CREATE INDEX "Claim_tenantId_status_idx" ON "Claim"("tenantId", "status");

-- CreateIndex
CREATE INDEX "Partner_tenantId_name_idx" ON "Partner"("tenantId", "name");

-- CreateIndex
CREATE UNIQUE INDEX "Ownership_assetId_partnerId_key" ON "Ownership"("assetId", "partnerId");

-- CreateIndex
CREATE UNIQUE INDEX "TenantSettings_tenantId_key" ON "TenantSettings"("tenantId");

-- AddForeignKey
ALTER TABLE "UserTenant" ADD CONSTRAINT "UserTenant_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UserTenant" ADD CONSTRAINT "UserTenant_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RefreshToken" ADD CONSTRAINT "RefreshToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Client" ADD CONSTRAINT "Client_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Vehicle" ADD CONSTRAINT "Vehicle_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Rental" ADD CONSTRAINT "Rental_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Rental" ADD CONSTRAINT "Rental_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "Client"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Rental" ADD CONSTRAINT "Rental_vehicleId_fkey" FOREIGN KEY ("vehicleId") REFERENCES "Vehicle"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FinanceEntry" ADD CONSTRAINT "FinanceEntry_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MaintenanceOrder" ADD CONSTRAINT "MaintenanceOrder_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MaintenanceOrder" ADD CONSTRAINT "MaintenanceOrder_assetId_fkey" FOREIGN KEY ("assetId") REFERENCES "Vehicle"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NotificationTemplate" ADD CONSTRAINT "NotificationTemplate_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NotificationMessage" ADD CONSTRAINT "NotificationMessage_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NotificationMessage" ADD CONSTRAINT "NotificationMessage_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "Client"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NotificationMessage" ADD CONSTRAINT "NotificationMessage_rentalId_fkey" FOREIGN KEY ("rentalId") REFERENCES "Rental"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NotificationMessage" ADD CONSTRAINT "NotificationMessage_financeEntryId_fkey" FOREIGN KEY ("financeEntryId") REFERENCES "FinanceEntry"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Incident" ADD CONSTRAINT "Incident_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Incident" ADD CONSTRAINT "Incident_assetId_fkey" FOREIGN KEY ("assetId") REFERENCES "Vehicle"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Incident" ADD CONSTRAINT "Incident_rentalId_fkey" FOREIGN KEY ("rentalId") REFERENCES "Rental"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Insurer" ADD CONSTRAINT "Insurer_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "InsurancePolicy" ADD CONSTRAINT "InsurancePolicy_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "InsurancePolicy" ADD CONSTRAINT "InsurancePolicy_assetId_fkey" FOREIGN KEY ("assetId") REFERENCES "Vehicle"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "InsurancePolicy" ADD CONSTRAINT "InsurancePolicy_insurerId_fkey" FOREIGN KEY ("insurerId") REFERENCES "Insurer"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Claim" ADD CONSTRAINT "Claim_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Claim" ADD CONSTRAINT "Claim_policyId_fkey" FOREIGN KEY ("policyId") REFERENCES "InsurancePolicy"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Claim" ADD CONSTRAINT "Claim_incidentId_fkey" FOREIGN KEY ("incidentId") REFERENCES "Incident"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Partner" ADD CONSTRAINT "Partner_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Ownership" ADD CONSTRAINT "Ownership_assetId_fkey" FOREIGN KEY ("assetId") REFERENCES "Vehicle"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Ownership" ADD CONSTRAINT "Ownership_partnerId_fkey" FOREIGN KEY ("partnerId") REFERENCES "Partner"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TenantSettings" ADD CONSTRAINT "TenantSettings_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;
