-- AlterTable
ALTER TABLE "users" ADD COLUMN     "isIndigent" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "isPwd" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "isSenior" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "otp" TEXT,
ADD COLUMN     "otpExpires" TIMESTAMP(3),
ADD COLUMN     "otpType" TEXT,
ADD COLUMN     "verificationStatus" TEXT,
ADD COLUMN     "verificationStep" INTEGER;

