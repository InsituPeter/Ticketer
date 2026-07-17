-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('organizer', 'buyer');

-- CreateEnum
CREATE TYPE "EventStatus" AS ENUM ('active', 'cancelled', 'completed');

-- CreateEnum
CREATE TYPE "SeatStatus" AS ENUM ('open', 'held', 'sold', 'reserved');

-- CreateEnum
CREATE TYPE "OrderStatus" AS ENUM ('held', 'pending_payment', 'paid', 'failed', 'expired', 'refund_pending', 'refunded', 'resold', 'transferred');

-- CreateEnum
CREATE TYPE "RefundStatus" AS ENUM ('pending', 'approved', 'rejected', 'processed', 'failed');

-- CreateEnum
CREATE TYPE "ResaleStatus" AS ENUM ('active', 'sold', 'cancelled');

-- CreateEnum
CREATE TYPE "TransferStatus" AS ENUM ('pending', 'completed', 'cancelled');

-- CreateEnum
CREATE TYPE "NotificationType" AS ENUM ('payment_confirmed', 'refund_approved', 'refund_rejected', 'refund_auto_approved', 'resale_sold', 'resale_listing_cancelled', 'transfer_initiated', 'transfer_completed', 'transfer_received');

-- CreateEnum
CREATE TYPE "NotificationStatus" AS ENUM ('pending', 'sent', 'failed');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "email" TEXT NOT NULL,
    "password_hash" TEXT NOT NULL,
    "role" "UserRole" NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "events" (
    "id" UUID NOT NULL,
    "organizer_id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "venue" TEXT NOT NULL,
    "starts_at" TIMESTAMPTZ NOT NULL,
    "status" "EventStatus" NOT NULL DEFAULT 'active',
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "seats" (
    "id" UUID NOT NULL,
    "event_id" UUID NOT NULL,
    "label" TEXT NOT NULL,
    "price" DECIMAL(10,2) NOT NULL,
    "status" "SeatStatus" NOT NULL DEFAULT 'open',
    "version" INTEGER NOT NULL DEFAULT 1,

    CONSTRAINT "seats_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "orders" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "event_id" UUID NOT NULL,
    "seat_ids" TEXT[],
    "total" DECIMAL(10,2) NOT NULL,
    "status" "OrderStatus" NOT NULL,
    "idempotency_key" TEXT,
    "paystack_reference" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "orders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "refunds" (
    "id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "seat_ids" TEXT[],
    "amount" DECIMAL(10,2) NOT NULL,
    "status" "RefundStatus" NOT NULL,
    "auto_or_override" TEXT NOT NULL DEFAULT 'override',
    "reason" TEXT,
    "requested_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolved_at" TIMESTAMPTZ,
    "resolved_by" UUID,
    "idempotency_key" TEXT,

    CONSTRAINT "refunds_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "resale_listings" (
    "id" UUID NOT NULL,
    "seat_id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "seller_id" UUID NOT NULL,
    "face_value" DECIMAL(10,2) NOT NULL,
    "service_fee" DECIMAL(10,2) NOT NULL,
    "list_price" DECIMAL(10,2) NOT NULL,
    "status" "ResaleStatus" NOT NULL DEFAULT 'active',
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "resale_listings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "transfers" (
    "id" UUID NOT NULL,
    "seat_id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "from_user_id" UUID NOT NULL,
    "to_user_id" UUID NOT NULL,
    "fee" DECIMAL(10,2) NOT NULL,
    "status" "TransferStatus" NOT NULL,
    "paystack_reference" TEXT,
    "idempotency_key" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "transfers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "type" "NotificationType" NOT NULL,
    "channel" TEXT NOT NULL DEFAULT 'email',
    "status" "NotificationStatus" NOT NULL DEFAULT 'pending',
    "payload" JSONB,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE INDEX "seats_event_id_idx" ON "seats"("event_id");

-- CreateIndex
CREATE UNIQUE INDEX "seats_event_id_label_key" ON "seats"("event_id", "label");

-- CreateIndex
CREATE UNIQUE INDEX "orders_idempotency_key_key" ON "orders"("idempotency_key");

-- CreateIndex
CREATE INDEX "orders_user_id_idx" ON "orders"("user_id");

-- CreateIndex
CREATE INDEX "orders_event_id_idx" ON "orders"("event_id");

-- CreateIndex
CREATE INDEX "orders_status_idx" ON "orders"("status");

-- CreateIndex
CREATE UNIQUE INDEX "refunds_idempotency_key_key" ON "refunds"("idempotency_key");

-- CreateIndex
CREATE INDEX "refunds_order_id_idx" ON "refunds"("order_id");

-- CreateIndex
CREATE INDEX "refunds_status_idx" ON "refunds"("status");

-- CreateIndex
CREATE UNIQUE INDEX "resale_listings_seat_id_key" ON "resale_listings"("seat_id");

-- CreateIndex
CREATE UNIQUE INDEX "transfers_idempotency_key_key" ON "transfers"("idempotency_key");

-- AddForeignKey
ALTER TABLE "events" ADD CONSTRAINT "events_organizer_id_fkey" FOREIGN KEY ("organizer_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "seats" ADD CONSTRAINT "seats_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "orders" ADD CONSTRAINT "orders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "orders" ADD CONSTRAINT "orders_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "refunds" ADD CONSTRAINT "refunds_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "refunds" ADD CONSTRAINT "refunds_resolved_by_fkey" FOREIGN KEY ("resolved_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "resale_listings" ADD CONSTRAINT "resale_listings_seat_id_fkey" FOREIGN KEY ("seat_id") REFERENCES "seats"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "resale_listings" ADD CONSTRAINT "resale_listings_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "resale_listings" ADD CONSTRAINT "resale_listings_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "transfers" ADD CONSTRAINT "transfers_seat_id_fkey" FOREIGN KEY ("seat_id") REFERENCES "seats"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "transfers" ADD CONSTRAINT "transfers_from_user_id_fkey" FOREIGN KEY ("from_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "transfers" ADD CONSTRAINT "transfers_to_user_id_fkey" FOREIGN KEY ("to_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
