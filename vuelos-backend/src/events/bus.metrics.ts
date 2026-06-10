// Observabilidad del Event Bus — métricas en tiempo real por consumer.
// Expuesto vía GET /api/v1/health/bus para monitorear el estado del bus.
export type ConsumerName = 'catalog' | 'booking' | 'audit' | 'payments';

interface ConsumerStats {
  processed:    number;
  duplicates:   number;
  errors:       number;
  lastEventAt:  string | null;
  lastEventType: string | null;
}

const initial = (): ConsumerStats => ({
  processed:    0,
  duplicates:   0,
  errors:       0,
  lastEventAt:  null,
  lastEventType: null,
});

const metrics: Record<ConsumerName, ConsumerStats> = {
  catalog:  initial(),
  booking:  initial(),
  audit:    initial(),
  payments: initial(),
};

const startedAt = new Date().toISOString();

export function recordProcessed(consumer: ConsumerName, eventType: string): void {
  metrics[consumer].processed++;
  metrics[consumer].lastEventAt   = new Date().toISOString();
  metrics[consumer].lastEventType = eventType;
}

export function recordDuplicate(consumer: ConsumerName): void {
  metrics[consumer].duplicates++;
}

export function recordError(consumer: ConsumerName): void {
  metrics[consumer].errors++;
}

export function getBusMetrics() {
  return {
    startedAt,
    consumers: { ...metrics },
    totals: {
      processed:  Object.values(metrics).reduce((s, c) => s + c.processed,  0),
      duplicates: Object.values(metrics).reduce((s, c) => s + c.duplicates, 0),
      errors:     Object.values(metrics).reduce((s, c) => s + c.errors,     0),
    },
  };
}
