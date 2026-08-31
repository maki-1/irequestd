-- DropIndex
DROP INDEX "admins_username_key";

-- AlterTable
ALTER TABLE "admins" DROP COLUMN "name",
DROP COLUMN "username",
ADD COLUMN     "email" TEXT NOT NULL,
ADD COLUMN     "fullName" TEXT NOT NULL,
ADD COLUMN     "oauthId" TEXT,
ADD COLUMN     "oauthProvider" TEXT,
ADD COLUMN     "purok" TEXT NOT NULL DEFAULT '',
ALTER COLUMN "password" DROP NOT NULL,
DROP COLUMN "role",
ADD COLUMN     "role" TEXT NOT NULL DEFAULT 'Secretary';

-- DropEnum
DROP TYPE "AdminRole";

-- CreateTable
CREATE TABLE "audit_trails" (
    "id" UUID NOT NULL,
    "legacyId" VARCHAR(24),
    "adminId" UUID,
    "username" TEXT,
    "role" TEXT,
    "action" TEXT NOT NULL,
    "details" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "audit_trails_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" UUID NOT NULL,
    "legacyId" VARCHAR(24),
    "adminId" UUID NOT NULL,
    "message" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'Unread',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payments" (
    "id" UUID NOT NULL,
    "legacyId" VARCHAR(24),
    "userId" UUID NOT NULL,
    "documentId" UUID,
    "documentType" TEXT,
    "amount" DECIMAL(10,2) NOT NULL,
    "provider" TEXT NOT NULL,
    "sessionId" TEXT,
    "paymentId" TEXT,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "legacyRequestIds" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "documents" (
    "id" UUID NOT NULL,
    "legacyId" VARCHAR(24),
    "customId" TEXT,
    "createdById" UUID,
    "fullName" TEXT NOT NULL,
    "age" INTEGER,
    "gender" TEXT,
    "dateOfBirth" TIMESTAMP(3),
    "maritalStatus" TEXT,
    "purok" TEXT,
    "contactNumber" TEXT,
    "email" TEXT,
    "residentType" TEXT NOT NULL DEFAULT 'Regular',
    "ipMember" BOOLEAN NOT NULL DEFAULT false,
    "ethnicGroup" TEXT,
    "registeredVoter" BOOLEAN NOT NULL DEFAULT false,
    "documentType" TEXT NOT NULL,
    "requestDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "purpose" TEXT,
    "status" TEXT NOT NULL DEFAULT 'Pending',
    "paymentStatus" TEXT NOT NULL DEFAULT 'Pending',
    "documentFee" DECIMAL(10,2) NOT NULL DEFAULT 130,
    "receiptFile" TEXT,
    "orNumber" TEXT,
    "signatureStatus" TEXT NOT NULL DEFAULT '',
    "sealStatus" TEXT NOT NULL DEFAULT '',
    "residentPhoto" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "documents_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "_PaymentRequests" (
    "A" UUID NOT NULL,
    "B" UUID NOT NULL,

    CONSTRAINT "_PaymentRequests_AB_pkey" PRIMARY KEY ("A","B")
);

-- CreateIndex
CREATE UNIQUE INDEX "audit_trails_legacyId_key" ON "audit_trails"("legacyId");

-- CreateIndex
CREATE INDEX "audit_trails_adminId_idx" ON "audit_trails"("adminId");

-- CreateIndex
CREATE INDEX "audit_trails_createdAt_idx" ON "audit_trails"("createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "notifications_legacyId_key" ON "notifications"("legacyId");

-- CreateIndex
CREATE INDEX "notifications_adminId_status_idx" ON "notifications"("adminId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "payments_legacyId_key" ON "payments"("legacyId");

-- CreateIndex
CREATE INDEX "payments_userId_idx" ON "payments"("userId");

-- CreateIndex
CREATE INDEX "payments_sessionId_idx" ON "payments"("sessionId");

-- CreateIndex
CREATE UNIQUE INDEX "documents_legacyId_key" ON "documents"("legacyId");

-- CreateIndex
CREATE UNIQUE INDEX "documents_customId_key" ON "documents"("customId");

-- CreateIndex
CREATE INDEX "documents_status_idx" ON "documents"("status");

-- CreateIndex
CREATE INDEX "_PaymentRequests_B_index" ON "_PaymentRequests"("B");

-- CreateIndex
CREATE UNIQUE INDEX "admins_email_key" ON "admins"("email");

-- AddForeignKey
ALTER TABLE "audit_trails" ADD CONSTRAINT "audit_trails_adminId_fkey" FOREIGN KEY ("adminId") REFERENCES "admins"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_adminId_fkey" FOREIGN KEY ("adminId") REFERENCES "admins"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_documentId_fkey" FOREIGN KEY ("documentId") REFERENCES "documents"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "documents" ADD CONSTRAINT "documents_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "admins"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "_PaymentRequests" ADD CONSTRAINT "_PaymentRequests_A_fkey" FOREIGN KEY ("A") REFERENCES "payments"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "_PaymentRequests" ADD CONSTRAINT "_PaymentRequests_B_fkey" FOREIGN KEY ("B") REFERENCES "requests"("id") ON DELETE CASCADE ON UPDATE CASCADE;

