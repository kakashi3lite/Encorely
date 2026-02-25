# Architecture Patterns

Comprehensive reference for software architecture patterns used in modern, scalable systems.

## Table of Contents

- [Layered Architecture](#layered-architecture)
- [Microservices Architecture](#microservices-architecture)
- [Event-Driven Architecture](#event-driven-architecture)
- [CQRS and Event Sourcing](#cqrs-and-event-sourcing)
- [API Gateway Pattern](#api-gateway-pattern)
- [Repository Pattern](#repository-pattern)
- [Anti-Patterns to Avoid](#anti-patterns-to-avoid)

---

## Layered Architecture

### Overview

Organizes code into horizontal layers where each layer has a specific responsibility and communicates only with adjacent layers.

### Layers

| Layer | Responsibility | Examples |
|-------|---------------|---------|
| Presentation | UI / API interface | React, Next.js, Express routes |
| Application | Business logic | Services, use cases |
| Domain | Core entities and rules | Models, domain events |
| Infrastructure | External systems | Database, queues, file storage |

### Best Practices

- Keep business logic in the domain/application layer, never in the presentation layer.
- Use dependency injection to decouple layers.
- Define clear interfaces between layers to allow independent testing.

### Code Example (Node.js)

```typescript
// Domain layer
class User {
  constructor(public readonly id: string, public email: string) {}
}

// Application layer (service)
class UserService {
  constructor(private readonly userRepository: UserRepository) {}

  async getUser(id: string): Promise<User> {
    return this.userRepository.findById(id);
  }
}

// Infrastructure layer (repository implementation)
class PostgresUserRepository implements UserRepository {
  async findById(id: string): Promise<User> {
    const row = await db.query("SELECT * FROM users WHERE id = $1", [id]);
    return new User(row.id, row.email);
  }
}
```

---

## Microservices Architecture

### Overview

Decomposes an application into small, independently deployable services that communicate over a network.

### Principles

- **Single Responsibility**: Each service owns one business domain.
- **Loose Coupling**: Services communicate via APIs or events, not shared databases.
- **High Cohesion**: Related functionality is grouped together.
- **Independent Deployability**: Each service can be deployed without affecting others.

### Communication Patterns

| Pattern | Use Case | Technology |
|---------|----------|-----------|
| Synchronous REST | Simple request/response | Express, FastAPI |
| Synchronous GraphQL | Flexible queries | Apollo Server |
| Asynchronous events | Decoupled workflows | Kafka, RabbitMQ, SQS |
| gRPC | High-performance internal calls | gRPC + Protobuf |

### Best Practices

- Use an API gateway as the single entry point for clients.
- Implement circuit breakers to prevent cascading failures.
- Use distributed tracing (OpenTelemetry) across services.
- Each service manages its own database schema.

---

## Event-Driven Architecture

### Overview

Services communicate by producing and consuming events, enabling loose coupling and scalability.

### Components

- **Event Producer**: Emits events when state changes occur.
- **Event Broker**: Routes events to consumers (Kafka, SQS, EventBridge).
- **Event Consumer**: Reacts to events and performs actions.

### Example Event Flow

```
User Service → "user.created" → Event Broker → Email Service (sends welcome email)
                                             → Analytics Service (tracks signup)
                                             → Billing Service (creates trial account)
```

### Best Practices

- Define events with a clear schema (use JSON Schema or Protobuf).
- Include event versioning to support schema evolution.
- Implement idempotent consumers to handle duplicate events.
- Store events for replay capability (event log).

---

## CQRS and Event Sourcing

### CQRS (Command Query Responsibility Segregation)

Separates read (query) and write (command) models for scalability.

```
Client → Command → Write Model → Database (normalized)
Client → Query  → Read Model  → Read Store (denormalized/cached)
```

### Event Sourcing

Stores state as a sequence of events rather than current state.

```typescript
// Events stored, not current state
const events = [
  { type: "AccountOpened", amount: 0 },
  { type: "MoneyDeposited", amount: 100 },
  { type: "MoneyWithdrawn", amount: 30 },
];

// Current state derived by replaying events
const balance = events.reduce((acc, event) => {
  if (event.type === "MoneyDeposited") return acc + event.amount;
  if (event.type === "MoneyWithdrawn") return acc - event.amount;
  return acc;
}, 0); // balance = 70
```

### When to Use

- Complex business domains requiring audit trails.
- Systems needing temporal queries ("what was the state at time T?").
- High-scale write-heavy workloads.

---

## API Gateway Pattern

### Overview

A single entry point for all client requests that routes to appropriate backend services.

### Responsibilities

- **Authentication & Authorization**: Validate tokens before forwarding requests.
- **Rate Limiting**: Prevent abuse by limiting requests per client.
- **Request Routing**: Forward requests to the correct microservice.
- **Response Aggregation**: Combine responses from multiple services.
- **Protocol Translation**: e.g., REST to gRPC.

### Implementation Example

```typescript
// Express API Gateway
app.use("/users", authenticate, rateLimit, proxy("http://user-service:3001"));
app.use("/products", authenticate, rateLimit, proxy("http://product-service:3002"));
app.use("/orders", authenticate, rateLimit, proxy("http://order-service:3003"));
```

---

## Repository Pattern

### Overview

Abstracts data access logic behind an interface, decoupling business logic from storage concerns.

### Benefits

- Easy to swap storage backends (PostgreSQL → MongoDB).
- Simplifies unit testing by mocking the repository interface.
- Centralizes query logic.

### Example (TypeScript)

```typescript
interface UserRepository {
  findById(id: string): Promise<User | null>;
  findByEmail(email: string): Promise<User | null>;
  save(user: User): Promise<void>;
  delete(id: string): Promise<void>;
}

class PrismaUserRepository implements UserRepository {
  async findById(id: string): Promise<User | null> {
    return prisma.user.findUnique({ where: { id } });
  }
  // ... other methods
}
```

---

## Anti-Patterns to Avoid

### Big Ball of Mud

**Problem**: No clear structure; all code is tangled together.  
**Solution**: Apply layered architecture and enforce module boundaries.

### Distributed Monolith

**Problem**: Microservices that share databases or are tightly coupled via synchronous calls.  
**Solution**: Each service owns its data; use events for inter-service communication.

### God Object / God Service

**Problem**: One class or service does everything.  
**Solution**: Apply the Single Responsibility Principle; split into focused services.

### Premature Microservices

**Problem**: Splitting into microservices before understanding domain boundaries leads to wrong splits.  
**Solution**: Start with a modular monolith; extract services when boundaries become clear.

### Chatty Interfaces

**Problem**: Services making many fine-grained calls to each other, creating network overhead.  
**Solution**: Design coarse-grained APIs; use batch endpoints; consider GraphQL for flexible queries.

---

## Real-World Scenarios

### E-Commerce Platform

```
Client App (React/Next.js)
    ↓
API Gateway (rate limiting, auth)
    ↓
┌──────────┬──────────┬──────────┐
│  Users   │ Products │  Orders  │
│ Service  │ Service  │ Service  │
└──────────┴──────────┴──────────┘
    ↓              ↓         ↓
PostgreSQL    PostgreSQL   PostgreSQL
                    ↓
              Event Broker (Kafka)
                    ↓
         ┌──────────────────┐
         │ Notification Svc │
         └──────────────────┘
```

### Mobile App Backend (React Native / Swift / Kotlin)

- Use GraphQL API to reduce over-fetching for mobile clients.
- Implement push notification service for real-time updates.
- Use CDN for static assets and images.
- Implement offline-first with local SQLite and sync on reconnect.
