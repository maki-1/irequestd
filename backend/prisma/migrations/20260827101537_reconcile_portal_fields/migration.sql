-- AlterTable
ALTER TABLE "completed_documents" ADD COLUMN     "address" TEXT,
ADD COLUMN     "age" INTEGER,
ADD COLUMN     "fullName" TEXT,
ADD COLUMN     "purok" TEXT,
ADD COLUMN     "purpose" TEXT;

-- AlterTable
ALTER TABLE "requests" ADD COLUMN     "claimCode" TEXT,
ADD COLUMN     "paymentLinkId" TEXT,
ADD COLUMN     "purokLeaderAt" TIMESTAMP(3),
ADD COLUMN     "purokLeaderBy" UUID,
ADD COLUMN     "purokLeaderRemarks" TEXT NOT NULL DEFAULT '',
ADD COLUMN     "yearsAtAddress" INTEGER,
DROP COLUMN "status",
ADD COLUMN     "status" TEXT NOT NULL DEFAULT 'Pending';

-- DropEnum
DROP TYPE "RequestStatus";

-- CreateIndex
CREATE INDEX "requests_status_idx" ON "requests"("status");

-- AddForeignKey
ALTER TABLE "requests" ADD CONSTRAINT "requests_purokLeaderBy_fkey" FOREIGN KEY ("purokLeaderBy") REFERENCES "admins"("id") ON DELETE SET NULL ON UPDATE CASCADE;

