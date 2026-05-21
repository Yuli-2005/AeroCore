import * as grpc from '@grpc/grpc-js';
import * as protoLoader from '@grpc/proto-loader';
import path from 'path';
import { fileURLToPath } from 'url';
import jwt from 'jsonwebtoken';
import { PrismaClient } from './prisma-client/index.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Inicializar Prisma para buscar el usuario administrador y obtener la firma
const prisma = new PrismaClient();

async function runTest() {
  console.log("🔍 Buscando usuario administrador en la base de datos...");
  const adminUser = await prisma.user.findFirst({
    where: { role: 'ADMIN', isActive: true },
  });

  if (!adminUser) {
    console.error("❌ No se encontró ningún usuario administrador activo en la base de datos.");
    process.exit(1);
  }

  console.log(`👤 Usuario administrador encontrado: ${adminUser.email}`);

  // Leer secretos del entorno para firmar el token
  const JWT_SECRET = process.env.JWT_SECRET || "7f5b128c70bfcd757b3bf2d1cfa976b91bc62ff8b4de8cfd0b2f56b6b7a9de3c";
  const JWT_ISSUER = process.env.JWT_ISSUER || "vuelos-api";
  const JWT_AUDIENCE = process.env.JWT_AUDIENCE || "vuelos-client";

  // Firmar un token JWT válido
  const token = jwt.sign(
    {
      id: adminUser.id,
      email: adminUser.email,
      role: adminUser.role,
      tokenVersion: adminUser.tokenVersion,
    },
    JWT_SECRET,
    {
      issuer: JWT_ISSUER,
      audience: JWT_AUDIENCE,
      expiresIn: '2h',
    }
  );

  console.log("🔑 Token JWT de servicio generado con éxito.");

  // Cargar el archivo .proto
  const PROTO_PATH = path.join(__dirname, 'src', 'grpc', 'proto', 'flights.proto');
  const packageDefinition = protoLoader.loadSync(PROTO_PATH, {
    keepCase: true,
    longs: String,
    enums: String,
    defaults: true,
    oneofs: true,
  });

  const protoDescriptor = grpc.loadPackageDefinition(packageDefinition) as any;
  const vuelosPackage = protoDescriptor.vuelos?.v1;

  if (!vuelosPackage) {
    console.error("❌ No se pudo cargar el paquete de vuelos de gRPC.");
    process.exit(1);
  }

  // Crear el cliente gRPC
  const client = new vuelosPackage.FlightService(
    'localhost:50051',
    grpc.credentials.createInsecure()
  );

  // Crear metadatos e inyectar el Bearer Token
  const metadata = new grpc.Metadata();
  metadata.add('authorization', `Bearer ${token}`);

  console.log("📡 Conectando al servidor gRPC local en localhost:50051...");
  console.log("🔍 Enviando petición gRPC SearchFlights...");

  client.SearchFlights(
    {
      origin: 'UIO',
      destination: 'BOG',
      date: '2026-05-21',
      passengers: 1,
      cabin_class: 'ECONOMY',
    },
    metadata,
    (err: any, response: any) => {
      if (err) {
        console.error("❌ Error en la llamada gRPC:", err.message);
        process.exit(1);
      }
      console.log("✅ Respuesta recibida con éxito desde el Servidor gRPC:");
      console.log(JSON.stringify(response, null, 2));
      process.exit(0);
    }
  );
}

runTest().catch((err) => {
  console.error("❌ Error ejecutando la prueba:", err);
  process.exit(1);
});
