# System Design Workflows

Step-by-step processes for designing, building, and optimizing software systems.

## Table of Contents

- [System Design Process](#system-design-process)
- [Requirements Gathering](#requirements-gathering)
- [Capacity Planning](#capacity-planning)
- [Database Design](#database-design)
- [API Design](#api-design)
- [Performance Optimization](#performance-optimization)
- [Observability Setup](#observability-setup)
- [Troubleshooting Guide](#troubleshooting-guide)

---

## System Design Process

### Step-by-Step Workflow

1. **Clarify Requirements**
   - Functional requirements: What does the system do?
   - Non-functional requirements: Scale, latency, availability, consistency.
   - Constraints: Budget, team size, timeline, existing infrastructure.

2. **Estimate Scale**
   - Daily/monthly active users (DAU/MAU).
   - Read vs. write ratio.
   - Data volume and growth rate.
   - Peak traffic patterns.

3. **Define System Boundaries**
   - Identify core components.
   - Define external integrations.
   - Establish API contracts.

4. **Choose Technology Stack**
   - Use the Tech Decision Guide (`references/tech_decision_guide.md`).
   - Evaluate trade-offs for each component.
   - Prefer proven technologies over novelty.

5. **Design Data Model**
   - Identify entities and relationships.
   - Choose storage type (relational, document, key-value, graph).
   - Plan for indexing and query patterns.

6. **Design APIs**
   - Define endpoints and operations.
   - Specify request/response schemas.
   - Plan authentication and authorization.

7. **Plan for Scale**
   - Horizontal vs. vertical scaling strategy.
   - Caching strategy.
   - Database replication and sharding.
   - CDN for static assets.

8. **Review and Iterate**
   - Identify single points of failure.
   - Review security considerations.
   - Estimate costs.
   - Get peer review.

---

## Requirements Gathering

### Functional Requirements Checklist

- [ ] Core user journeys documented
- [ ] Edge cases identified
- [ ] Error handling defined
- [ ] Admin/internal workflows documented
- [ ] Third-party integrations listed

### Non-Functional Requirements

| Requirement | Questions to Ask |
|------------|-----------------|
| Availability | What is the acceptable downtime? 99.9% = ~8.7h/year |
| Latency | What is the p99 response time target? |
| Consistency | Strong or eventual consistency? |
| Durability | What is acceptable data loss? (RPO) |
| Recovery | How quickly must the system recover? (RTO) |
| Security | Compliance requirements (GDPR, HIPAA, SOC2)? |

---

## Capacity Planning

### Estimation Formula

```
Requests per second (RPS) = DAU × avg_requests_per_day / 86400

Storage per year = daily_data_created × 365 × replication_factor

Bandwidth = avg_request_size × RPS
```

### Example: Music Streaming App

```
Users: 1M DAU
Each user plays 10 songs/day = 10M plays/day
RPS = 10M / 86400 ≈ 116 RPS (peak: ~3-5x = 400 RPS)

Audio file size: 5 MB average
Storage/day = 10M × 5 MB = 50 TB (with deduplication: ~5 TB new content/day)

Bandwidth = 5 MB × 116 RPS = 580 MB/s = 4.6 Gbps
```

### Scaling Thresholds

| Component | Scale At |
|----------|----------|
| Single DB instance | > 10,000 RPS or > 1 TB data |
| Single API server | > 1,000 concurrent connections |
| Single cache node | > 80% memory utilization |
| Single message broker | > 50,000 messages/second |

---

## Database Design

### Workflow

1. **Identify Access Patterns** before choosing a database type.
2. **Normalize first**, then denormalize for performance where needed.
3. **Plan indexes** based on query patterns (avoid over-indexing).
4. **Design for growth**: use UUIDs or distributed IDs, avoid serial integers at scale.
5. **Plan migrations**: use tools like Flyway, Liquibase, or Prisma Migrate.

### PostgreSQL Schema Example

```sql
-- Users table with proper indexing
CREATE TABLE users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email       VARCHAR(255) UNIQUE NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);

-- Use partial indexes for filtered queries
CREATE INDEX idx_users_active ON users(created_at) WHERE deleted_at IS NULL;
```

### Choosing Storage Type

| Use Case | Recommended Storage |
|---------|-------------------|
| Relational data with complex queries | PostgreSQL |
| Flexible document storage | MongoDB, Firestore |
| High-speed caching | Redis |
| Time-series data | TimescaleDB, InfluxDB |
| Full-text search | Elasticsearch, Typesense |
| Graph relationships | Neo4j |
| Object/file storage | S3, GCS |

---

## API Design

### REST API Design Checklist

- [ ] Use nouns for resources, not verbs (`/users`, not `/getUsers`)
- [ ] Use proper HTTP methods (GET, POST, PUT, PATCH, DELETE)
- [ ] Return appropriate status codes (200, 201, 400, 401, 403, 404, 500)
- [ ] Version the API (`/v1/users`)
- [ ] Use pagination for list endpoints
- [ ] Validate and sanitize all inputs
- [ ] Document with OpenAPI/Swagger

### GraphQL Design Checklist

- [ ] Design schema around use cases, not database structure
- [ ] Use DataLoader to batch and cache database calls
- [ ] Implement query depth and complexity limits
- [ ] Use subscriptions for real-time data
- [ ] Implement proper error handling

### Pagination Patterns

```typescript
// Cursor-based pagination (recommended for large datasets)
interface PaginatedResponse<T> {
  data: T[];
  pageInfo: {
    hasNextPage: boolean;
    endCursor: string | null;
  };
}

// Offset pagination (simpler but less efficient at scale)
interface OffsetPaginatedResponse<T> {
  data: T[];
  total: number;
  page: number;
  pageSize: number;
}
```

---

## Performance Optimization

### Optimization Workflow

1. **Measure first**: Use profiling tools before optimizing.
2. **Identify bottleneck**: CPU, memory, I/O, or network?
3. **Fix the biggest bottleneck**: Focus on the constraint.
4. **Re-measure**: Verify improvement.
5. **Repeat** until targets are met.

### Caching Strategy

```
L1: In-memory cache (process-level, e.g., node-cache) - microseconds
L2: Distributed cache (Redis) - < 1ms
L3: CDN cache (CloudFront) - < 10ms
L4: Database query cache - 10-100ms
```

### Cache Invalidation Patterns

| Pattern | When to Use |
|---------|------------|
| TTL (time-to-live) | Data that's acceptable to be slightly stale |
| Write-through | Data must be consistent immediately after writes |
| Cache-aside | Large datasets where only hot data should be cached |
| Event-driven invalidation | Cache cleared when domain events occur |

### Database Query Optimization

```sql
-- Use EXPLAIN ANALYZE to find slow queries
EXPLAIN ANALYZE SELECT * FROM orders WHERE user_id = '...' ORDER BY created_at DESC;

-- Common fixes:
-- 1. Add missing index
CREATE INDEX CONCURRENTLY idx_orders_user_created ON orders(user_id, created_at DESC);

-- 2. Avoid N+1 queries - use JOINs or batch loading
SELECT u.*, COUNT(o.id) as order_count
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
GROUP BY u.id;
```

---

## Observability Setup

### Three Pillars

| Pillar | Tool Examples | What It Answers |
|--------|-------------|----------------|
| Metrics | Prometheus, Datadog | Is the system healthy? |
| Logs | Loki, CloudWatch, Splunk | What happened? |
| Traces | Jaeger, Tempo, X-Ray | Where is the bottleneck? |

### Key Metrics to Track

```
# Application metrics
- Request rate (RPS)
- Error rate (%)
- Latency (p50, p95, p99)
- Saturation (CPU %, memory %)

# Business metrics
- Active users
- Feature usage
- Conversion rates
- Revenue per minute
```

### Alerting Guidelines

- Alert on symptoms (high error rate), not causes (high CPU).
- Set alert thresholds based on SLOs.
- Use multi-window, multi-burn-rate alerts for SLO alerting.
- Avoid alert fatigue: every alert must be actionable.

---

## Tool Integrations

### CI/CD Pipeline Stages

```yaml
# GitHub Actions example
stages:
  - lint          # ESLint, SwiftLint, Pylint
  - test          # Unit tests, integration tests
  - build         # Compile/bundle
  - security-scan # SAST, dependency audit
  - deploy-staging
  - integration-test
  - deploy-production
```

### Infrastructure as Code

```hcl
# Terraform example for RDS PostgreSQL
resource "aws_db_instance" "main" {
  identifier        = "app-db"
  engine            = "postgres"
  engine_version    = "15.4"
  instance_class    = "db.t3.medium"
  allocated_storage = 100
  storage_encrypted = true
  multi_az          = true
}
```

---

## Troubleshooting Guide

### High Latency

1. Check p99 vs p50 latency — if p99 >> p50, suspect slow database queries.
2. Check cache hit rate — low hit rate means frequent slow DB calls.
3. Check network latency between services.
4. Look for N+1 query patterns in application logs.
5. Check for lock contention in the database.

### High Error Rate

1. Check recent deployments — did a deploy precede the spike?
2. Check downstream dependencies — are external APIs failing?
3. Review error logs for patterns.
4. Check resource exhaustion (connection pool full, memory OOM).
5. Verify configuration changes.

### Database Performance Degradation

1. Run `EXPLAIN ANALYZE` on slow queries.
2. Check for missing indexes (`pg_stat_user_tables`).
3. Look for long-running transactions (`pg_stat_activity`).
4. Check vacuum statistics (`pg_stat_user_tables.n_dead_tup`).
5. Review connection pool utilization.

### Memory Leaks (Node.js)

```bash
# Generate heap snapshot
node --inspect app.js

# Analyze with Chrome DevTools or:
npm install -g clinic
clinic heapprofiler -- node app.js
```
