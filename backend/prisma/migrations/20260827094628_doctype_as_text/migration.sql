/*
  Warnings:

  - Changed the type of `documentType` on the `requests` table. No cast exists, the column would be dropped and recreated, which cannot be done if there is data, since the column is required.
  - Changed the type of `deliveryMethod` on the `requests` table. No cast exists, the column would be dropped and recreated, which cannot be done if there is data, since the column is required.

*/
-- AlterTable
ALTER TABLE "requests" DROP COLUMN "documentType",
ADD COLUMN     "documentType" TEXT NOT NULL,
DROP COLUMN "deliveryMethod",
ADD COLUMN     "deliveryMethod" TEXT NOT NULL;

-- DropEnum
DROP TYPE "DeliveryMethod";

-- DropEnum
DROP TYPE "DocumentType";
