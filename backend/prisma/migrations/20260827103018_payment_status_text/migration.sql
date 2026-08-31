-- AlterTable
ALTER TABLE "requests" DROP COLUMN "paymentStatus",
ADD COLUMN     "paymentStatus" TEXT NOT NULL DEFAULT 'unpaid',
ALTER COLUMN "deliveryMethod" SET DEFAULT 'Pick up at Barangay Office';

-- DropEnum
DROP TYPE "PaymentStatus";

