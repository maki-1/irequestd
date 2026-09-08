-- AlterTable
ALTER TABLE "verification_profiles" ADD COLUMN     "isSoloParent" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "isIndigenousPeople" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "isPregnant" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "isNonResident" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "ethnicGroup" TEXT;
