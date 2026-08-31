-- AlterTable
ALTER TABLE "payments" ADD COLUMN     "adminId" UUID,
ALTER COLUMN "userId" DROP NOT NULL;

-- CreateIndex
CREATE INDEX "payments_adminId_idx" ON "payments"("adminId");

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_adminId_fkey" FOREIGN KEY ("adminId") REFERENCES "admins"("id") ON DELETE SET NULL ON UPDATE CASCADE;

