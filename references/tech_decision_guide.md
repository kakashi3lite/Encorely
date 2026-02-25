# Tech Decision Guide

Technical reference for choosing technologies, configuring environments, and building scalable systems.

## Table of Contents

- [Technology Stack Overview](#technology-stack-overview)
- [Frontend Decisions](#frontend-decisions)
- [Backend Decisions](#backend-decisions)
- [Database Decisions](#database-decisions)
- [Mobile Decisions](#mobile-decisions)
- [DevOps and Infrastructure](#devops-and-infrastructure)
- [Integration Patterns](#integration-patterns)
- [Security Considerations](#security-considerations)
- [Scalability Guidelines](#scalability-guidelines)
- [Configuration Examples](#configuration-examples)
- [Troubleshooting](#troubleshooting)

---

## Technology Stack Overview

| Layer | Primary Choice | Alternatives | Avoid When |
|-------|---------------|-------------|-----------|
| Web Frontend | Next.js (React) | Vue/Nuxt, SvelteKit | SEO not needed + heavy interactivity |
| Mobile | React Native | Flutter, Swift, Kotlin | Platform-specific APIs dominate |
| API | Node.js + Express | Go (Gin/Echo), Python (FastAPI) | CPU-intensive without workers |
| GraphQL | Apollo Server | Pothos, Yoga | Simple CRUD with no flexibility needs |
| Database | PostgreSQL | MySQL, SQLite | Non-relational data |
| Cache | Redis | Memcached | Data requires persistence |
| Queue | AWS SQS / Kafka | RabbitMQ | Low-volume, no ordering needs |
| Search | Typesense | Elasticsearch | Full-text search not required |
| File Storage | AWS S3 | GCS, Cloudflare R2 | Small file volumes |

---

## Frontend Decisions

### Next.js vs. Plain React

| Factor | Next.js | Plain React (CRA/Vite) |
|--------|---------|----------------------|
| SEO requirements | ✅ Built-in SSR/SSG | ❌ Requires extra setup |
| Performance | ✅ Automatic code splitting | ⚠️ Manual optimization |
| Full-stack | ✅ API routes | ❌ Separate backend needed |
| Learning curve | ⚠️ Slightly steeper | ✅ Simpler |

**Recommendation**: Use Next.js for most web applications. Use plain React only for internal tools or SPAs with no SEO requirements.

### State Management

| Library | Use Case |
|---------|----------|
| React Query / TanStack Query | Server state (API data fetching and caching) |
| Zustand | Simple global client state |
| Redux Toolkit | Complex client state with time-travel debugging |
| Jotai / Recoil | Atomic state in large apps |

**Recommendation**: Use React Query for server state + Zustand for client state. Avoid Redux unless the team already uses it.

### Styling

| Approach | Best For |
|----------|---------|
| Tailwind CSS | Rapid development, consistent design |
| CSS Modules | Component-scoped styles, no runtime |
| Styled Components / Emotion | Dynamic styles based on props |
| shadcn/ui | Pre-built accessible components with Tailwind |

---

## Backend Decisions

### Node.js vs. Go vs. Python

| Factor | Node.js | Go | Python |
|--------|---------|-----|--------|
| I/O-heavy workloads | ✅ Excellent | ✅ Excellent | ⚠️ Good |
| CPU-intensive tasks | ❌ Single-threaded | ✅ Excellent | ⚠️ Use with workers |
| Development speed | ✅ Fast | ⚠️ Moderate | ✅ Fastest |
| Type safety | ✅ TypeScript | ✅ Built-in | ⚠️ Optional (mypy) |
| Ecosystem | ✅ Largest | ⚠️ Growing | ✅ Rich (ML/AI) |
| Performance | ⚠️ Good | ✅ Excellent | ⚠️ Slower (CPython) |

**Recommendation**:
- Use **Node.js + TypeScript** for APIs that are primarily I/O bound.
- Use **Go** for high-performance services, CLI tools, or infrastructure components.
- Use **Python** for ML/AI, data pipelines, and scripts.

### REST vs. GraphQL

| Factor | REST | GraphQL |
|--------|------|---------|
| Simplicity | ✅ Simple | ⚠️ More complex setup |
| Over-fetching | ❌ Common issue | ✅ Client controls fields |
| Multiple resources | ❌ Multiple requests | ✅ Single request |
| Caching | ✅ HTTP caching | ⚠️ Requires custom caching |
| Mobile clients | ⚠️ Multiple endpoints | ✅ Efficient for mobile |

**Recommendation**: Use GraphQL when you have multiple clients (web, mobile) with different data needs. Use REST for simple, stable APIs with few consumers.

---

## Database Decisions

### PostgreSQL Configuration

```sql
-- Recommended settings for production (postgresql.conf)
-- Adjust based on available RAM

-- Memory
shared_buffers = 25% of RAM          -- e.g., 4GB for 16GB server
effective_cache_size = 75% of RAM    -- e.g., 12GB for 16GB server
work_mem = 64MB                      -- Per query operation
maintenance_work_mem = 1GB           -- For VACUUM, CREATE INDEX

-- Connections
max_connections = 100                -- Use connection pooling (PgBouncer)

-- Write performance
wal_buffers = 64MB
checkpoint_completion_target = 0.9
synchronous_commit = on              -- Set to 'off' only if you can tolerate data loss
```

### Connection Pooling with PgBouncer

```ini
[databases]
myapp = host=localhost port=5432 dbname=myapp

[pgbouncer]
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 25
```

### Prisma Setup (Node.js)

```typescript
// prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id @default(uuid())
  email     String   @unique
  createdAt DateTime @default(now()) @map("created_at")
  updatedAt DateTime @updatedAt @map("updated_at")

  @@map("users")
}
```

---

## Mobile Decisions

### React Native vs. Flutter vs. Native

| Factor | React Native | Flutter | Swift (iOS) | Kotlin (Android) |
|--------|-------------|---------|-------------|-----------------|
| Code sharing | ✅ 70-90% shared | ✅ 95%+ shared | ❌ iOS only | ❌ Android only |
| Performance | ⚠️ Good | ✅ Excellent | ✅ Best | ✅ Best |
| Native feel | ⚠️ Mostly native | ⚠️ Custom renderer | ✅ Native | ✅ Native |
| Web dev familiarity | ✅ JS/TS | ⚠️ Dart | ❌ Swift | ❌ Kotlin |
| Platform APIs | ⚠️ Bridge overhead | ⚠️ Bridge overhead | ✅ Direct | ✅ Direct |

**Recommendation**:
- Use **React Native** when team knows JS/TS and needs cross-platform.
- Use **Flutter** for pixel-perfect cross-platform UIs or non-standard designs.
- Use **Swift/Kotlin** when deep platform integration is required or performance is critical.

---

## DevOps and Infrastructure

### Docker Best Practices

```dockerfile
# Multi-stage build for Node.js
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
EXPOSE 3000
CMD ["node", "dist/server.js"]
```

### Kubernetes Resource Limits

```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
spec:
  replicas: 3
  template:
    spec:
      containers:
        - name: api
          image: app:latest
          resources:
            requests:
              memory: "256Mi"
              cpu: "250m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          livenessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /ready
              port: 3000
```

### GitHub Actions CI Template

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"
      - run: npm ci
      - run: npm run lint
      - run: npm test
      - run: npm run build
```

---

## Integration Patterns

### Third-Party API Integration

```typescript
// Resilient API client with retry and circuit breaker
class ApiClient {
  private retryCount = 3;

  async request<T>(url: string, options?: RequestInit): Promise<T> {
    for (let attempt = 1; attempt <= this.retryCount; attempt++) {
      try {
        const response = await fetch(url, options);
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return response.json();
      } catch (error) {
        if (attempt === this.retryCount) throw error;
        await this.sleep(Math.pow(2, attempt) * 100); // Exponential backoff
      }
    }
    throw new Error("Max retries reached");
  }

  private sleep(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
```

### Webhook Handling

```typescript
// Verify webhook signature before processing
app.post("/webhooks/stripe", express.raw({ type: "application/json" }), (req, res) => {
  const sig = req.headers["stripe-signature"];
  let event;

  try {
    event = stripe.webhooks.constructEvent(req.body, sig, process.env.STRIPE_WEBHOOK_SECRET);
  } catch (err) {
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  // Process event asynchronously - respond quickly
  processWebhookAsync(event).catch(console.error);
  res.json({ received: true });
});
```

---

## Security Considerations

### Authentication

- Use **JWT** for stateless APIs; store in `httpOnly` cookies, not `localStorage`.
- Use **short-lived access tokens** (15 min) with **refresh tokens** (7 days).
- Implement **OAuth 2.0 / OIDC** via providers (Auth0, Clerk, Supabase Auth) rather than rolling your own.
- Enforce **MFA** for admin accounts.

### Input Validation

```typescript
// Use Zod for runtime type validation
import { z } from "zod";

const CreateUserSchema = z.object({
  email: z.string().email().toLowerCase(),
  password: z.string().min(12).max(128),
  name: z.string().min(1).max(100).trim(),
});

app.post("/users", async (req, res) => {
  const result = CreateUserSchema.safeParse(req.body);
  if (!result.success) {
    return res.status(400).json({ errors: result.error.issues });
  }
  // Safe to use result.data
});
```

### Database Security

- Use **parameterized queries** — never concatenate user input into SQL.
- Use **least privilege**: app DB user should only have SELECT/INSERT/UPDATE/DELETE, not DDL.
- **Encrypt sensitive data** at rest (use `pgcrypto` or application-level encryption).
- Rotate credentials regularly; use secrets managers (AWS Secrets Manager, HashiCorp Vault).

### Dependency Security

```bash
# Audit dependencies regularly
npm audit
pip-audit  # pip install pip-audit
snyk test  # npm install -g snyk

# Keep dependencies updated
npm outdated
pip list --outdated
```

---

## Scalability Guidelines

### Horizontal Scaling Checklist

- [ ] Application is **stateless** (no in-memory session state)
- [ ] Sessions stored in **Redis** or database
- [ ] File uploads go to **object storage** (S3), not local disk
- [ ] Scheduled jobs use **distributed locks** to avoid duplicate execution
- [ ] Database connections use a **connection pool**
- [ ] **Health check endpoints** (`/health`, `/ready`) implemented

### Vertical Scaling Limits

| Resource | Scale Vertically Until | Then Do |
|----------|----------------------|--------|
| CPU | ~32 cores | Horizontal scaling or distribute work |
| RAM | ~256 GB | Shard data or use distributed cache |
| Database | ~4 TB SSD | Read replicas, then sharding |
| Network | ~25 Gbps | CDN, edge computing |

### Database Scaling Path

```
Single DB
  ↓ (> 10k RPS or > 1TB)
Read Replicas (for read-heavy workloads)
  ↓ (still bottlenecked)
Connection Pooling with PgBouncer
  ↓ (still bottlenecked)
Caching Layer (Redis for hot data)
  ↓ (write-heavy bottleneck)
Vertical scaling of primary
  ↓ (extreme scale needed)
Sharding (partition by user/tenant)
```

---

## Configuration Examples

### Environment Variables (.env.example)

```bash
# Application
NODE_ENV=development
PORT=3000
APP_URL=http://localhost:3000

# Database
DATABASE_URL=postgresql://user:password@localhost:5432/myapp
DATABASE_POOL_SIZE=10

# Redis
REDIS_URL=redis://localhost:6379

# Authentication
JWT_SECRET=your-secret-key-min-32-chars
JWT_EXPIRY=15m
REFRESH_TOKEN_EXPIRY=7d

# External Services
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
SENDGRID_API_KEY=SG....
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_S3_BUCKET=my-app-assets
AWS_REGION=us-east-1
```

---

## Troubleshooting

### Deployment Failures

1. **Image build fails**: Check Dockerfile syntax; verify base image availability.
2. **Container won't start**: Check environment variables; verify database connectivity.
3. **Health check failing**: Ensure `/health` endpoint responds within timeout.
4. **Out of memory**: Increase memory limits; check for memory leaks.

### Database Connection Issues

```bash
# Test database connectivity
psql $DATABASE_URL -c "SELECT 1"

# Check connection pool exhaustion
SELECT count(*) FROM pg_stat_activity WHERE state = 'active';

# Check for blocking queries
SELECT pid, query, wait_event_type, wait_event
FROM pg_stat_activity
WHERE state = 'active' AND wait_event IS NOT NULL;
```

### High Memory Usage (Node.js)

```bash
# Enable heap profiling
node --heap-prof app.js

# Use clinic for detailed profiling
npm install -g clinic
clinic doctor -- node app.js
```

### API Rate Limiting Issues

- Implement exponential backoff in clients.
- Use caching to reduce redundant API calls.
- Check if rate limits apply per IP, user, or API key.
- Consider upgrading API tier or requesting limit increases.
