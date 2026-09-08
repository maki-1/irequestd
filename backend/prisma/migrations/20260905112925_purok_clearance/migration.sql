-- AlterTable
ALTER TABLE "requests" ADD COLUMN     "purokClearanceId" UUID;

-- CreateTable
CREATE TABLE "purok_clearances" (
    "id" UUID NOT NULL,
    "controlNo" TEXT NOT NULL,
    "purok" TEXT NOT NULL,
    "issuedById" UUID NOT NULL,
    "userId" UUID,
    "fullName" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "birthday" TIMESTAMP(3),
    "contactNumber" TEXT,
    "feecentavos" INTEGER NOT NULL DEFAULT 0,
    "feePaid" BOOLEAN NOT NULL DEFAULT true,
    "issuedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "validUntil" TIMESTAMP(3),
    "status" TEXT NOT NULL DEFAULT 'issued',
    "usedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "purok_clearances_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "purok_clearances_controlNo_key" ON "purok_clearances"("controlNo");

-- CreateIndex
CREATE INDEX "purok_clearances_status_idx" ON "purok_clearances"("status");

-- CreateIndex
CREATE INDEX "purok_clearances_purok_idx" ON "purok_clearances"("purok");

-- CreateIndex
CREATE INDEX "purok_clearances_userId_idx" ON "purok_clearances"("userId");

-- AddForeignKey
ALTER TABLE "purok_clearances" ADD CONSTRAINT "purok_clearances_issuedById_fkey" FOREIGN KEY ("issuedById") REFERENCES "admins"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purok_clearances" ADD CONSTRAINT "purok_clearances_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "requests" ADD CONSTRAINT "requests_purokClearanceId_fkey" FOREIGN KEY ("purokClearanceId") REFERENCES "purok_clearances"("id") ON DELETE SET NULL ON UPDATE CASCADE;

