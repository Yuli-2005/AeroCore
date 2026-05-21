import { execSync } from 'child_process';

const databases = [
  { name: 'ms_identity (stdgavgnqdrvxiedblmy)', url: 'postgresql://postgres:Yuli%402005%2C.%2C@db.stdgavgnqdrvxiedblmy.supabase.co:5432/postgres' },
  { name: 'ms_catalog (hsdzimksgiajklxbjzaa)', url: 'postgresql://postgres:Yuli%402005%2C.%2C@db.hsdzimksgiajklxbjzaa.supabase.co:5432/postgres' },
  { name: 'ms_booking (fxxxqmajmkyizeacxdmz)', url: 'postgresql://postgres:Yuli%402005%2C.%2C@db.fxxxqmajmkyizeacxdmz.supabase.co:5432/postgres' },
  { name: 'ms_payments (yscdzivpnaslvzhhdgzf)', url: 'postgresql://postgres:Yuli%402005%2C.%2C@db.yscdzivpnaslvzhhdgzf.supabase.co:5432/postgres' }
];

console.log('🚀 Iniciando sincronización de las 4 bases de datos de Supabase...\n');

for (const db of databases) {
  console.log(`--------------------------------------------------`);
  console.log(`📦 Sincronizando base de datos: ${db.name}`);
  console.log(`--------------------------------------------------`);
  
  try {
    // Ejecutar npx prisma db push con la URL de la base de datos específica
    console.log(`👉 Ejecutando 'prisma db push' para crear esquemas y tablas...`);
    execSync('npx prisma db push --skip-generate', {
      env: { ...process.env, DATABASE_URL: db.url },
      stdio: 'inherit'
    });
    console.log(`✅ Esquemas y tablas sincronizados con éxito.`);

    // Ejecutar la siembra de datos semilla (seed)
    console.log(`👉 Ejecutando 'prisma db seed' para sembrar datos iniciales...`);
    execSync('npx tsx prisma/seed.ts', {
      env: { ...process.env, DATABASE_URL: db.url },
      stdio: 'inherit'
    });
    console.log(`✅ Datos semilla cargados con éxito.\n`);

  } catch (error) {
    console.error(`❌ Error al sincronizar la base de datos ${db.name}:`, error.message);
  }
}

console.log('🎉 ¡Proceso de sincronización completado para las 4 bases de datos!');
