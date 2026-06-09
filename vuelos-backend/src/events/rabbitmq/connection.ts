// events/rabbitmq/connection.ts
// Gestiona la conexión única a RabbitMQ con reconexión automática.
import amqplib from 'amqplib';
import { setupTopology } from './topology.js';

// amqplib exporta tipos complejos — usamos any para compatibilidad
let connection: any = null;
let channel:    any = null;
let reconnecting = false;

const RETRY_DELAY_MS = 5000;
const url = () => process.env.RABBITMQ_URL ?? 'amqp://localhost';

export async function connectRabbitMQ(): Promise<any> {
  try {
    console.log('[RabbitMQ] conectando...');
    connection = await amqplib.connect(url());
    channel    = await connection.createChannel();

    await setupTopology(channel);

    console.log('[RabbitMQ] ✅ conectado y topología lista');

    // Si la conexión se cierra inesperadamente → reconectar
    connection.on('close', () => {
      if (reconnecting) return;
      reconnecting = true;
      console.warn(`[RabbitMQ] ⚠️  conexión cerrada. Reintentando en ${RETRY_DELAY_MS / 1000}s...`);
      channel    = null;
      connection = null;
      setTimeout(async () => {
        reconnecting = false;
        await connectRabbitMQ().catch(console.error);
      }, RETRY_DELAY_MS);
    });

    connection.on('error', (err: Error) => {
      console.error('[RabbitMQ] ❌ error de conexión:', err.message);
    });

    return channel;

  } catch (err: any) {
    console.error('[RabbitMQ] ❌ no se pudo conectar:', err.message);
    console.warn(`[RabbitMQ] Reintentando en ${RETRY_DELAY_MS / 1000}s...`);
    await new Promise(r => setTimeout(r, RETRY_DELAY_MS));
    return connectRabbitMQ();
  }
}

// Retorna el canal activo. Todos los producers y consumers lo usan.
export function getChannel(): any {
  if (!channel) throw new Error('[RabbitMQ] Canal no disponible. ¿connectRabbitMQ() fue llamado?');
  return channel;
}

export async function closeRabbitMQ(): Promise<void> {
  try {
    await channel?.close();
    await connection?.close();
    console.log('[RabbitMQ] conexión cerrada limpiamente');
  } catch {
    // ignorar errores al cerrar
  }
}
