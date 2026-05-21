import prisma from '../shared/database/prisma.client.js';

const cities = await (prisma as any).city.findMany({
  include: { country: true }
});

console.log('\n🏙️ Ciudades en la base de datos:\n');
for (const city of cities) {
  console.log(`  Nombre: ${city.name} (${city.country.name})`);
  console.log(`  cityId: ${city.id}`);
  console.log('  ---');
}

await (prisma as any).$disconnect();
