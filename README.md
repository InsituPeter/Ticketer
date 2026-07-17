# Ticketer

Backend API for a ticketing application with atomic holds, Paystack
payments, WebSocket broadcasts, refunds, resale, transfers, fraud
detection, and resale price suggestions. Frontend to be built later
in a separate repo.

## Features

- **Atomic seat holds** — Redis TTL-based holds prevent double-booking with automatic expiration
- **Paystack payments** — Secure payment processing with idempotent transactions
- **Real-time updates** — WebSocket broadcasts for seat status changes
- **Resale marketplace** — List purchased seats for resale with automatic fee handling
- **Resale price suggestions** — Heuristic-based pricing suggestions for resale listings
- **Seat transfers** — Transfer seats between users with fee processing
- **Refund management** — Manual and auto-refund windows (configurable, default 48h)
- **Fraud detection** — Rule-based detection for velocity, bulk purchases, bots, and payment retries
- **Waiting room** — Configurable capacity limits per event
- **Idempotent operations** — Redis-backed idempotency keys prevent duplicate processing
- **Role-based access** — Organizer and buyer roles with JWT + refresh token authentication

## Tech Stack

| Layer | Technology |
|-------|------------|
| Runtime | Node.js 22 (ESM) |
| Language | TypeScript 6 (strict mode, ES2022 target) |
| Framework | Express 5 |
| Database | PostgreSQL 16 |
| ORM | Prisma 6 |
| Cache | Redis 7 (ioredis) |
| Queue | BullMQ |
| Auth | JWT (jsonwebtoken + bcryptjs) |
| Payments | Paystack |
| Email | Postmark |
| Realtime | WebSocket (ws) |
| Validation | Zod 4 |
| Testing | Jest + Supertest + Testcontainers + k6 |
| Container | Docker + Docker Compose |

## Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/) 22 or later
- [Docker](https://www.docker.com/) and [Docker Compose](https://docs.docker.com/compose/)
- [Git](https://git-scm.com/)

### Installation

```bash
# Clone the repository
git clone <repo-url>
cd ticketer

# Install dependencies
npm install

# Set up environment variables
cp .env.example .env
# Edit .env with your values (see Environment Variables below)
```

### Start Development

```bash
# Start databases (Postgres + Redis)
npm run docker:up

# Run database migrations
npm run db:migrate

# Start dev server with hot reload
npm run dev
```

The server starts at **http://localhost:8810**.

### Verify

```bash
# Health check
curl http://localhost:8810/health
# → { "status": "ok", "timestamp": "..." }
```

## Environment Variables

Copy `.env.example` to `.env` and configure:

### Server

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8810` | Server port |
| `NODE_ENV` | `development` | `development`, `production`, or `test` |

### Database

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | `postgresql://postgres:postgres@localhost:5432/ticketer` | PostgreSQL connection string |

### Redis

| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_URL` | `redis://localhost:6379` | Redis connection string |

### Authentication

| Variable | Default | Description |
|----------|---------|-------------|
| `JWT_SECRET` | — | Secret key for access token signing (min 1 char) |
| `JWT_REFRESH_SECRET` | — | Secret key for refresh token signing (min 1 char) |

Access token TTL: 1 hour (hardcoded). Refresh token TTL: 7 days (hardcoded).

### Payments (Paystack)

| Variable | Default | Description |
|----------|---------|-------------|
| `PAYSTACK_SECRET_KEY` | — | Paystack secret API key |
| `PAYSTACK_PUBLIC_KEY` | — | Paystack public API key |

### Email (Postmark)

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTMARK_SERVER_TOKEN` | — | Postmark server token |

### Business Config

| Variable | Default | Description |
|----------|---------|-------------|
| `HOLD_TTL_SECONDS` | `300` | Seat hold expiration (5 minutes) |
| `WAITING_ROOM_CAP` | `50` | Max concurrent waiting room users |
| `AUTO_REFUND_WINDOW_HOURS` | `48` | Hours before auto-refund expires |
| `SERVICE_FEE_FLAT` | `500` | Flat service fee (in currency smallest unit) |
| `TRANSFER_FEE_FLAT` | `500` | Flat transfer fee (in currency smallest unit) |

### Fraud Detection

| Variable | Default | Description |
|----------|---------|-------------|
| `FRAUD_MAX_HOLDS` | `10` | Max holds per user within window |
| `FRAUD_HOLD_WINDOW_MIN` | `10` | Hold velocity window (minutes) |
| `FRAUD_MAX_SEATS_PER_EVENT` | `8` | Max seats a user can buy per event |
| `FRAUD_MIN_REQUEST_INTERVAL_MS` | `500` | Min ms between requests (bot detection) |
| `FRAUD_MAX_FAILED_PAYMENTS` | `5` | Max failed payments within window |
| `FRAUD_PAYMENT_WINDOW_MIN` | `15` | Payment retry window (minutes) |

## Project Structure

```
ticketer/
├── prisma/
│   └── schema.prisma          # Database schema (10 models)
├── src/
│   ├── config/
│   │   └── index.ts           # Zod-validated environment config
│   ├── lib/
│   │   └── prisma.ts          # PrismaClient singleton
│   ├── errors/
│   │   ├── index.ts           # Barrel export
│   │   ├── AppError.ts        # Base error class
│   │   ├── UnauthorizedError.ts   # 401
│   │   ├── ForbiddenError.ts      # 403
│   │   ├── NotFoundError.ts       # 404
│   │   ├── ConflictError.ts       # 409
│   │   ├── HoldExpiredError.ts    # 410
│   │   └── ValidationError.ts     # 422
│   ├── middleware/
│   │   ├── validate.ts        # Zod validation → ValidationError
│   │   ├── errorHandler.ts    # Global error handler
│   │   ├── auth.ts            # JWT verification, attaches req.user
│   │   ├── fraud.ts           # Fraud detection middleware
│   │   └── idempotency.ts     # Redis idempotency keys
│   ├── redis/
│   │   └── client.ts          # ioredis singleton
│   ├── repositories/
│   │   ├── userRepository.ts  # User CRUD
│   │   └── refreshTokenRepository.ts # Refresh token CRUD
│   ├── service/
│   │   ├── authService.ts     # Register, login, refresh, logoutAll, JWT helpers
│   │   ├── fraudService.ts    # Rule-based fraud detection
│   │   ├── resalePricingService.ts # Resale price suggestions
│   │   └── userService.ts     # User management
│   ├── routes/                # Express route files
│   ├── validation/            # Zod schemas (one per resource)
│   ├── ws/
│   │   └── index.ts           # WebSocket upgrade handler
│   ├── app.ts                 # Express app factory
│   └── server.ts              # Entry point + graceful shutdown
├── tests/
│   ├── unit/                  # Unit tests (Jest)
│   ├── integration/           # Integration tests (Testcontainers)
│   └── load/                  # Load tests (k6)
├── docker-compose.dev.yml     # Dev databases only
├── docker-compose.yml         # Production full stack
├── Dockerfile                 # Single-stage production build
├── tsconfig.json              # TypeScript config
├── jest.config.ts             # Jest config (ts-jest ESM)
├── .prettierrc                # Prettier config
├── .husky/pre-commit          # Pre-commit hook
└── package.json
```

## Database Schema

### Models

| Model | Description |
|-------|-------------|
| **User** | Organizers and buyers with email/password auth, roles array |
| **RefreshToken** | Refresh tokens with expiry, linked to user |
| **Event** | Ticketed events with name, venue, start time |
| **Seat** | Individual seats with price, status, optimistic locking (`version`) |
| **Order** | Purchase orders tracking seat IDs, totals, payment status |
| **Refund** | Refund requests with approval workflow |
| **ResaleListing** | Seats listed for resale with pricing breakdown |
| **Transfer** | Seat transfers between users |
| **Notification** | Email notifications with status tracking |

### Seat Status Flow

```
open → held → sold
  ↓       ↓
  ↓    (expired) → open
  ↓
 reserved (admin)
```

### Order Status Flow

```
held → pending_payment → paid
         ↓                 ↓
       failed            refunded → resold/transferred
         ↓
       expired
```

### Key Constraints

- All primary keys are UUIDs (`@db.Uuid`)
- Money fields use `Decimal(10, 2)`
- Unique seat labels per event: `@@unique([eventId, label])`
- Idempotency keys on Order, Refund, Transfer
- Unique token on RefreshToken
- Optimistic locking on seats via `version` field
- User roles stored as PostgreSQL array (`UserRole[]`)

## API Design

### Auth Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/auth/register` | No | Create account with initial role → token pair |
| POST | `/auth/login` | No | Verify credentials → token pair |
| POST | `/auth/refresh` | No | Rotate refresh token → new pair |
| POST | `/auth/logout-all` | Yes | Delete all refresh tokens for user |
| PATCH | `/auth/roles` | Yes | Add a role (e.g., buyer → organizer) |

### Core Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/health` | No | Health check |
| POST | `/events` | Yes (organizer) | Create event |
| GET | `/events/:id` | No | Get event details |
| PUT | `/events/:id` | Yes (organizer) | Update event |
| DELETE | `/events/:id` | Yes (organizer) | Cancel event |
| GET | `/events/:id/seats` | No | List seats for event |
| POST | `/events/:id/seats` | Yes (organizer) | Add seats |
| POST | `/seats/:id/hold` | Yes (buyer) | Hold seat (5min TTL) |
| POST | `/orders` | Yes (buyer) | Create order from held seats |
| POST | `/orders/:id/pay` | Yes (buyer) | Process payment via Paystack |
| POST | `/orders/:id/refund` | Yes (buyer) | Request refund |
| POST | `/resale` | Yes (buyer) | List seat for resale |
| POST | `/resale/:id/buy` | Yes (buyer) | Buy resale listing |
| POST | `/transfers` | Yes (buyer) | Initiate seat transfer |
| GET | `/notifications` | Yes | List user notifications |

### Request/Response Format

**Success:**
```json
{
  "data": { ... }
}
```

**Error:**
```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Event not found"
  }
}
```

**Validation Error:**
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": [
      { "path": "email", "message": "Invalid email" },
      { "path": "name", "message": "Required" }
    ]
  }
}
```

### Error Codes

| Code | Status | Description |
|------|--------|-------------|
| `UNAUTHORIZED` | 401 | Missing or invalid JWT |
| `INSUFFICIENT_PERMISSIONS` | 403 | Wrong role for action |
| `NOT_FOUND` | 404 | Resource doesn't exist |
| `SEAT_ALREADY_HELD` | 409 | Seat held by another user |
| `HOLD_EXPIRED` | 410 | Hold TTL expired |
| `VALIDATION_ERROR` | 422 | Request validation failed |
| `INTERNAL_SERVER_ERROR` | 500 | Unexpected error |

### Authentication

Include JWT in the `Authorization` header:

```
Authorization: Bearer <token>
```

Token payload:
```json
{
  "sub": "user-uuid",
  "roles": ["buyer"],
  "email": "user@example.com"
}
```

Password requirements: 8+ chars, 1 uppercase, 1 lowercase, 1 digit, 1 special character.

## Fraud Detection

Rule-based fraud detection (no ML). Runs as middleware on hold/purchase requests.

| Rule | Trigger | Action |
|------|---------|--------|
| Velocity | >10 holds from same user in 10 min | Block |
| Bulk limit | User buying >8 seats per event | Block |
| Bot detection | Request interval <500ms | Flag (log) |
| Payment retry | >5 failed payments in 15 min | Block |

All fraud data stored in Redis (ephemeral).

## Resale Price Suggestion

Heuristic-based pricing (no ML). Called when creating a resale listing.

```
suggestedPrice = faceValue * demandMultiplier * timeMultiplier * comparableMultiplier

Constraints:
  minPrice = faceValue * 0.8   (prevent deep discounting)
  maxPrice = faceValue * 2.0   (prevent gouging)
```

Seller can accept the suggestion or set their own price.

## Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Start dev server with hot reload (tsx watch) |
| `npm run build` | Compile TypeScript to `dist/` |
| `npm start` | Start production server |
| `npm run lint` | Type-check with `tsc --noEmit` |
| `npm run format` | Format all files with Prettier |
| `npm run format:check` | Check formatting without writing |
| `npm test` | Run unit tests (Jest) |
| `npm run test:watch` | Run tests in watch mode |
| `npm run test:coverage` | Run tests with coverage report |
| `npm run test:load` | Run k6 load tests |
| `npm run db:migrate` | Create/apply migration (dev) |
| `npm run db:migrate:deploy` | Apply migrations (production) |
| `npm run docker:up` | Start dev databases (Postgres + Redis) |
| `npm run docker:down` | Stop dev databases and remove volumes |
| `npm run docker:prod:up` | Start production stack |
| `npm run docker:prod:down` | Stop production stack |

## Docker

### Development (databases only)

```bash
npm run docker:up     # Postgres 16 + Redis 7
npm run docker:down   # Stop and remove volumes
```

### Production (full stack)

```bash
npm run docker:prod:up    # App + Postgres + Redis
npm run docker:prod:down  # Stop all services
```

### Docker Compose Files

| File | Services | Use Case |
|------|----------|----------|
| `docker-compose.dev.yml` | Postgres, Redis | Local development |
| `docker-compose.yml` | App, Postgres, Redis | Production deployment |

### Building the Image

```bash
docker build -t ticketer .
docker run -p 8810:8810 --env-file .env.production ticketer
```

The Dockerfile uses a single-stage build with Node.js 22 Alpine, runs `prisma generate` and `tsc` during build.

## Testing

### Unit Tests

```bash
npm test                    # Run once
npm run test:watch          # Watch mode
npm run test:coverage       # With coverage
```

### Integration Tests

Uses [Testcontainers](https://testcontainers.com/) to spin up real Postgres and Redis instances in Docker.

```bash
npm run test:integration    # (when available)
```

### Load Tests

Uses [k6](https://grafana.com/docs/k6/) for load testing concurrent holds.

```bash
npm run test:load           # k6 load test
```

## Development Workflow

### Code Style

- **No semicolons**
- **Single quotes**
- **Trailing commas** everywhere
- **2 space indent**, 100 char print width
- **ESM imports** (no `require()`)
- Prettier enforces on commit via Husky + lint-staged

### Adding a New Route

1. Create Zod schema in `src/validation/<resource>.ts`
2. Create route file in `src/routes/<resource>.ts`
3. Add error classes in `src/errors/` if needed
4. Mount route in `src/app.ts`
5. Add barrel export in `src/errors/index.ts`
6. Write tests in `tests/unit/` or `tests/integration/`

### Adding a New Error

1. Create `src/errors/<Name>Error.ts` extending `AppError`
2. Export from `src/errors/index.ts`
3. Use in route handlers: `throw new <Name>Error('message')`
4. Error handler catches and returns structured JSON

### Database Changes

```bash
# Edit prisma/schema.prisma
npm run db:migrate          # Creates migration + applies
npm run db:migrate:deploy   # Apply pending migrations (prod)
```

## License

MIT
