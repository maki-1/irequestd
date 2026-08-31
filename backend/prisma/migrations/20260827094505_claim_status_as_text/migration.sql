/*
  Warnings:

  - The `claimStatus` column on the `completed_documents` table would be dropped and recreated. This will lead to data loss if there is data in the column.

*/
-- AlterTable
ALTER TABLE "completed_documents" DROP COLUMN "claimStatus",
ADD COLUMN     "claimStatus" TEXT;

-- DropEnum
DROP TYPE "ClaimStatus";
