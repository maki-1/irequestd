-- AlterTable
ALTER TABLE "verification_profiles" ADD COLUMN     "aiVerification" JSONB,
ADD COLUMN     "civilStatus" TEXT,
ADD COLUMN     "contactNumber" TEXT,
ADD COLUMN     "email" TEXT,
ADD COLUMN     "governmentId" TEXT,
ADD COLUMN     "indigentProof" TEXT,
ADD COLUMN     "isIndigent" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "isSenior" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "nationality" TEXT,
ADD COLUMN     "proofOfResidency" TEXT,
ADD COLUMN     "pwdProof" TEXT,
ADD COLUMN     "remarks" TEXT NOT NULL DEFAULT '',
ADD COLUMN     "reviewedById" UUID,
ADD COLUMN     "secondaryId2Front" TEXT,
ADD COLUMN     "secondaryId2Name" TEXT,
ADD COLUMN     "secondaryId2Type" TEXT,
ADD COLUMN     "secondaryIdFront" TEXT,
ADD COLUMN     "secondaryIdName" TEXT,
ADD COLUMN     "secondaryIdType" TEXT,
ADD COLUMN     "selfieWithId" TEXT,
ADD COLUMN     "yearsAtAddress" INTEGER,
DROP COLUMN "status",
ADD COLUMN     "status" TEXT NOT NULL DEFAULT 'draft';

-- DropEnum
DROP TYPE "VerificationStatus";

-- CreateIndex
CREATE INDEX "verification_profiles_status_idx" ON "verification_profiles"("status");

-- AddForeignKey
ALTER TABLE "verification_profiles" ADD CONSTRAINT "verification_profiles_reviewedById_fkey" FOREIGN KEY ("reviewedById") REFERENCES "admins"("id") ON DELETE SET NULL ON UPDATE CASCADE;

