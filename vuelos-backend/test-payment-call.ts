import { prisma, paymentService } from './src/shared/container.js';

async function main() {
  console.log("Fetching last reservation...");
  const reservation = await prisma.reservation.findFirst({
    orderBy: { createdAt: 'desc' },
  });

  if (!reservation) {
    console.error("No reservations found in the database!");
    return;
  }

  console.log(`Testing payment for reservation: ${reservation.id} (Code: ${reservation.reservationCode})`);

  // Check if a payment already exists
  const existingPayment = await prisma.payment.findUnique({
    where: { reservationId: reservation.id }
  });
  if (existingPayment) {
    console.log("Payment already exists for this reservation:", existingPayment);
    // Delete it so we can test creating it again
    console.log("Deleting existing payment...");
    await prisma.payment.delete({ where: { reservationId: reservation.id } });
  }

  const payload = {
    reservationId: reservation.id,
    amount: Number(reservation.totalAmount),
    provider: 'VISA',
    transactionId: `TXN-TEST-${Date.now()}`,
    status: 'COMPLETED'
  };

  console.log("Payload to create payment:", payload);

  try {
    const result = await paymentService.create(payload, reservation.userId);
    console.log("Payment created successfully:", result);
  } catch (err: any) {
    console.error("Failed to create payment!");
    console.error(err);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch(console.error);
