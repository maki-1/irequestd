-- CreateEnum
CREATE TYPE "AdminRole" AS ENUM ('secretary', 'superadmin');

-- CreateEnum
CREATE TYPE "OtpType" AS ENUM ('register', 'reset');

-- CreateEnum
CREATE TYPE "DocumentType" AS ENUM ('Barangay Clearance', 'Certificate of Residency', 'Certificate of Indigency');

-- CreateEnum
CREATE TYPE "DeliveryMethod" AS ENUM ('Pick up at Barangay Office');

-- CreateEnum
CREATE TYPE "RequestStatus" AS ENUM ('Pending', 'Processing', 'Ready', 'Rejected');

-- CreateEnum
CREATE TYPE "PaymentStatus" AS ENUM ('unpaid', 'paid');

-- CreateEnum
CREATE TYPE "PurokLeaderStatus" AS ENUM ('pending', 'approved', 'rejected');

-- CreateEnum
CREATE TYPE "ClaimStatus" AS ENUM ('Pending', 'Claimed');

-- CreateEnum
CREATE TYPE "VerificationStatus" AS ENUM ('draft', 'pending', 'approved', 'rejected');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "legacyId" VARCHAR(24),
    "username" TEXT NOT NULL,
    "contactNumber" TEXT NOT NULL,
    "email" TEXT,
    "password" TEXT NOT NULL,
    "isVerified" BOOLEAN NOT NULL DEFAULT false,
    "avatar" TEXT NOT NULL DEFAULT '',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "admins" (
    "id" UUID NOT NULL,
    "legacyId" VARCHAR(24),
    "username" TEXT NOT NULL,
    "password" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "role" "AdminRole" NOT NULL DEFAULT 'secretary',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "admins_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "otp_codes" (
    "id" UUID NOT NULL,
    "legacyId" VARCHAR(24),
    "userId" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "type" "OtpType" NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "used" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "otp_codes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "requests" (
    "id" UUID NOT NULL,
    "legacyId" VARCHAR(24),
    "userId" UUID NOT NULL,
    "documentType" "DocumentType" NOT NULL,
    "purpose" TEXT NOT NULL,
    "additionalDetails" TEXT NOT NULL DEFAULT '',
    "deliveryMethod" "DeliveryMethod" NOT NULL,
    "status" "RequestStatus" NOT NULL DEFAULT 'Pending',
    "paymentStatus" "PaymentStatus" NOT NULL DEFAULT 'unpaid',
    "paymentSessionId" TEXT,
    "amountPaid" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "orNumber" TEXT,
    "freeDocumentProof" TEXT NOT NULL DEFAULT '',
    "requestPhoto" TEXT NOT NULL DEFAULT '',
    "controlNumber" TEXT NOT NULL DEFAULT '',
    "purokLeaderStatus" "PurokLeaderStatus" NOT NULL DEFAULT 'pending',
    "purokLeaderApprovedAt" TIMESTAMP(3),
    "purokClearanceFee" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "completed_documents" (
    "id" UUID NOT NULL,
    "legacyId" VARCHAR(24),
    "userId" UUID,
    "requestId" UUID,
    "documentType" TEXT,
    "claimCode" TEXT,
    "claimStatus" "ClaimStatus",
    "completedAt" TIMESTAMP(3),
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "completed_documents_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "counters" (
    "id" TEXT NOT NULL,
    "seq" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "counters_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "document_prices" (
    "id" UUID NOT NULL,
    "legacyId" VARCHAR(24),
    "documentType" TEXT NOT NULL,
    "pricecentavos" INTEGER NOT NULL,
    "description" TEXT NOT NULL DEFAULT '',
    "updatedBy" TEXT NOT NULL DEFAULT '',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "document_prices_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "purok_clearance_fee" (
    "id" UUID NOT NULL,
    "legacyId" VARCHAR(24),
    "purokName" TEXT NOT NULL,
    "feecentavos" INTEGER NOT NULL DEFAULT 0,
    "treasurerName" TEXT NOT NULL DEFAULT '',
    "purokPresident" TEXT NOT NULL DEFAULT '',
    "description" TEXT NOT NULL DEFAULT '',
    "updatedBy" TEXT NOT NULL DEFAULT '',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "purok_clearance_fee_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "verification_profiles" (
    "id" UUID NOT NULL,
    "legacyId" VARCHAR(24),
    "userId" UUID NOT NULL,
    "fullName" TEXT NOT NULL DEFAULT '',
    "address" TEXT NOT NULL DEFAULT '',
    "birthday" TIMESTAMP(3),
    "age" INTEGER,
    "gender" TEXT NOT NULL DEFAULT '',
    "indigent" TEXT NOT NULL DEFAULT '',
    "yearsOfResidency" TEXT NOT NULL DEFAULT '',
    "motherName" TEXT NOT NULL DEFAULT '',
    "fatherName" TEXT NOT NULL DEFAULT '',
    "isPwd" BOOLEAN NOT NULL DEFAULT false,
    "freeProofDocument" TEXT NOT NULL DEFAULT '',
    "educationLevel" TEXT NOT NULL DEFAULT '',
    "school" TEXT NOT NULL DEFAULT '',
    "yearGraduated" TEXT NOT NULL DEFAULT '',
    "course" TEXT NOT NULL DEFAULT '',
    "educationCertificate" TEXT NOT NULL DEFAULT '',
    "idType" TEXT NOT NULL DEFAULT '',
    "idName" TEXT NOT NULL DEFAULT '',
    "idFront" TEXT NOT NULL DEFAULT '',
    "idBack" TEXT NOT NULL DEFAULT '',
    "facePhoto" TEXT NOT NULL DEFAULT '',
    "idName2" TEXT NOT NULL DEFAULT '',
    "idFront2" TEXT NOT NULL DEFAULT '',
    "idBack2" TEXT NOT NULL DEFAULT '',
    "currentStep" INTEGER NOT NULL DEFAULT 1,
    "status" "VerificationStatus" NOT NULL DEFAULT 'draft',
    "rejectionReason" TEXT NOT NULL DEFAULT '',
    "submittedAt" TIMESTAMP(3),
    "reviewedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "verification_profiles_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_legacyId_key" ON "users"("legacyId");

-- CreateIndex
CREATE UNIQUE INDEX "users_username_key" ON "users"("username");

-- CreateIndex
CREATE UNIQUE INDEX "users_contactNumber_key" ON "users"("contactNumber");

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "admins_legacyId_key" ON "admins"("legacyId");

-- CreateIndex
CREATE UNIQUE INDEX "admins_username_key" ON "admins"("username");

-- CreateIndex
CREATE UNIQUE INDEX "otp_codes_legacyId_key" ON "otp_codes"("legacyId");

-- CreateIndex
CREATE INDEX "otp_codes_userId_type_idx" ON "otp_codes"("userId", "type");

-- CreateIndex
CREATE INDEX "otp_codes_expiresAt_idx" ON "otp_codes"("expiresAt");

-- CreateIndex
CREATE UNIQUE INDEX "requests_legacyId_key" ON "requests"("legacyId");

-- CreateIndex
CREATE UNIQUE INDEX "requests_orNumber_key" ON "requests"("orNumber");

-- CreateIndex
CREATE INDEX "requests_userId_idx" ON "requests"("userId");

-- CreateIndex
CREATE INDEX "requests_status_idx" ON "requests"("status");

-- CreateIndex
CREATE INDEX "requests_paymentSessionId_idx" ON "requests"("paymentSessionId");

-- CreateIndex
CREATE UNIQUE INDEX "completed_documents_legacyId_key" ON "completed_documents"("legacyId");

-- CreateIndex
CREATE INDEX "completed_documents_userId_idx" ON "completed_documents"("userId");

-- CreateIndex
CREATE INDEX "completed_documents_claimCode_idx" ON "completed_documents"("claimCode");

-- CreateIndex
CREATE UNIQUE INDEX "document_prices_legacyId_key" ON "document_prices"("legacyId");

-- CreateIndex
CREATE UNIQUE INDEX "document_prices_documentType_key" ON "document_prices"("documentType");

-- CreateIndex
CREATE UNIQUE INDEX "purok_clearance_fee_legacyId_key" ON "purok_clearance_fee"("legacyId");

-- CreateIndex
CREATE UNIQUE INDEX "purok_clearance_fee_purokName_key" ON "purok_clearance_fee"("purokName");

-- CreateIndex
CREATE UNIQUE INDEX "verification_profiles_legacyId_key" ON "verification_profiles"("legacyId");

-- CreateIndex
CREATE UNIQUE INDEX "verification_profiles_userId_key" ON "verification_profiles"("userId");

-- CreateIndex
CREATE INDEX "verification_profiles_status_idx" ON "verification_profiles"("status");

-- AddForeignKey
ALTER TABLE "otp_codes" ADD CONSTRAINT "otp_codes_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "requests" ADD CONSTRAINT "requests_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "completed_documents" ADD CONSTRAINT "completed_documents_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "completed_documents" ADD CONSTRAINT "completed_documents_requestId_fkey" FOREIGN KEY ("requestId") REFERENCES "requests"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "verification_profiles" ADD CONSTRAINT "verification_profiles_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
