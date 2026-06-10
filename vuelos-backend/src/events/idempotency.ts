// Idempotencia del Event Bus — evita procesar el mismo mensaje dos veces.
//
// RabbitMQ garantiza entrega "at-least-once": si un consumer cae después de
// procesar pero antes de hacer ACK, el mensaje se reencola y llega de nuevo.
// Este módulo detecta duplicados por messageId y los descarta.
//
// Almacenamiento: Set en memoria (se limpia al reiniciar, aceptable para demos).
// Si necesitas durabilidad, persiste los messageIds en Redis o una tabla DB.
const MAX_SIZE = 10_000;
const processed = new Set<string>();

export function isAlreadyProcessed(messageId: string): boolean {
  return processed.has(messageId);
}

export function markAsProcessed(messageId: string): void {
  if (processed.size >= MAX_SIZE) {
    // Elimina la entrada más antigua para mantener el tamaño acotado
    const oldest = processed.values().next().value as string;
    processed.delete(oldest);
  }
  processed.add(messageId);
}

export function getProcessedCount(): number {
  return processed.size;
}
