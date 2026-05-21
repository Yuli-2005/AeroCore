import * as grpc from '@grpc/grpc-js';
import * as protoLoader from '@grpc/proto-loader';
import path from 'path';
import { fileURLToPath } from 'url';
import jwt from 'jsonwebtoken';
import { getJwtSecret } from '../shared/security/jwt.config.js';
import prisma from '../shared/database/prisma.client.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROTO_PATH = path.join(__dirname, '../grpc/proto/flights.proto');

const packageDefinition = protoLoader.loadSync(PROTO_PATH, {
  keepCase: true,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true,
});

async function main() {
  // 1. Obtener el usuario admin del seed en la base de datos
  const user = await (prisma as any).user.findUnique({
    where: { email: 'admin@vuelosapp.com' },
  });

  if (!user) {
    console.error('❌ Error: No se encontró el usuario admin en la base de datos. Por favor corre npm run db:seed primero.');
    process.exit(1);
  }

  // 2. Firmar un token JWT válido
  const token = jwt.sign(
    {
      id: user.id,
      email: user.email,
      role: user.role,
      tokenVersion: user.tokenVersion,
    },
    getJwtSecret(),
    {
      issuer: process.env.JWT_ISSUER || 'vuelos-api',
      audience: process.env.JWT_AUDIENCE || 'vuelos-client',
      expiresIn: '2h',
    }
  );

  // 3. Crear cliente gRPC
  const vuelosProto = grpc.loadPackageDefinition(packageDefinition) as any;
  const client = new vuelosProto.vuelos.v1.FlightService(
    'localhost:50051',
    grpc.credentials.createInsecure()
  );

  // 4. Configurar Metadata con el token Bearer
  const metadata = new grpc.Metadata();
  metadata.add('authorization', `Bearer ${token}`);

  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  const dateString = tomorrow.toISOString().split('T')[0];

  console.log('📡 Enviando solicitud gRPC autenticada SearchFlights para la fecha:', dateString);

  client.SearchFlights(
    {
      origin: 'UIO',
      destination: 'BOG',
      date: dateString,
      passengers: 1,
      cabin_class: 'ECONOMY',
    },
    metadata, // metadata con token de autenticación
    (err: any, response: any) => {
      if (err) {
        console.error('❌ Error en gRPC:', err);
        process.exit(1);
      }
      console.log('✅ gRPC exitoso. Respuesta recibida:');
      console.log(JSON.stringify(response, null, 2));
      process.exit(0);
    }
  );
}

main().catch((err) => {
  console.error('❌ Error en el script de prueba:', err);
  process.exit(1);
});
