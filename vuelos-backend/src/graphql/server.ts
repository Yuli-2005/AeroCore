// graphql/server.ts
// Crea el servidor GraphQL Yoga listo para montarse en Express.
import { createYoga } from 'graphql-yoga';
import { schema } from './schema.js';

export const yoga = createYoga({
  schema,
  graphqlEndpoint: '/graphql',
  logging: false,
});