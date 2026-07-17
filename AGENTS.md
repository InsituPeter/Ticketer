# AGENTS.md — Ticketer

## Project Overview

Backend API for a ticketing application with atomic holds, Paystack
payments, WebSocket broadcasts, refunds, resale, transfers, fraud
detection, and resale price suggestions. Frontend to be built later
in a separate repo.

**Status:** Phase 1 scaffold in progress.

## Tech Stack

| Layer | Choice |
|-------|--------|
| Runtime | Node.js 22 (ESM `"type": "module"`) |
| Language | TypeScript 6, strict mode, ES2022 target |
| Framework | Express 5 |
| ORM | Prisma 6 (PostgreSQL 16) |
| Cache/Queue | Redis 7 (ioredis) + BullMQ |
| Auth | JWT (jsonwebtoken) + bcryptjs |
| Payments | Paystack |
| Email | Postmark |
| Realtime | WebSocket (ws) |
| Validation | Zod 4 |
| Testing | Jest 29 + ts-jest + supertest + testcontainers + k6 |
| Linting | tsc --noEmit (type-checking only) |
| Formatting | Prettier (no semis, single quotes, trailing commas) |
| Hooks | Husky + lint-staged |
| Container | Docker + Docker Compose (dev + prod) |

## Port

Server runs on **8810** (not 3000). All references use this port.

## File Structure

```
src/
  config/index.ts           — Zod-validated env, process.exit on failure
  lib/prisma.ts             — PrismaClient singleton
  errors/                   — Error classes (see Error Classes section)
  middleware/
    validate.ts             — Zod validation middleware (throws ValidationError)
    errorHandler.ts         — Global Express error handler (AppError → JSON)
    auth.ts                 — JWT verification, attaches req.user
    fraud.ts                — Fraud detection middleware (hold/purchase checks)
    idempotency.ts          — Redis idempotency key middleware
  redis/client.ts           — ioredis singleton
  repositories/
    userRepository.ts       — User CRUD
    refreshTokenRepository.ts — Refresh token CRUD
  routes/                   — Flat route files (events.ts, seats.ts, etc.)
  service/
    authService.ts          — Register, login, refresh, logoutAll, JWT helpers
    fraudService.ts         — Rule-based fraud detection
    resalePricingService.ts — Resale price suggestions
    userService.ts          — User management
  validation/               — Centralized Zod schemas
  ws/index.ts               — WebSocket upgrade handler (separate from HTTP)
  app.ts                    — Express bootstrap (no listen)
  server.ts                 — HTTP server + graceful shutdown
prisma/
  schema.prisma             — 10 models
tests/
  unit/                     — Unit tests (Jest)
  integration/              — Integration tests (Testcontainers)
  load/                     — k6 load tests
```

## Error Classes

**Base:** `AppError` extends `Error`
- Fields: `errorCode: string`, `statusCode: number`, `isOperational: boolean`, `timestamp: string`
- Constructor: `(errorCode, message, statusCode, isOperational = true)`
- Uses `Object.setPrototypeOf(this, new.target.prototype)` for correct `instanceof`

**Subclasses (6):**

| Class | Code | Status |
|-------|------|--------|
| `UnauthorizedError` | `UNAUTHORIZED` | 401 |
| `ForbiddenError` | `INSUFFICIENT_PERMISSIONS` | 403 |
| `NotFoundError` | `NOT_FOUND` | 404 |
| `ConflictError` | (dynamic) | 409 |
| `HoldExpiredError` | `HOLD_EXPIRED` | 410 |
| `ValidationError` | `VALIDATION_ERROR` | 422 |

**ValidationError** has additional field: `details: Array<{ path: string; message: string }>`

**Usage:**
```typescript
throw new UnauthorizedError()
throw new UnauthorizedError('Invalid token')
throw new ForbiddenError('Only the organizer can cancel')
throw new NotFoundError('Event not found')
throw new ConflictError('SEAT_ALREADY_HELD', 'Seat "A1" is already held')
throw new HoldExpiredError()
throw new ValidationError('Bad input', [{ path: 'email', message: 'Required' }])
```

## Middleware

### validate(schema, target?)
- Zod validation middleware
- `target` defaults to `'body'`, can be `'query'` or `'params'`
- Throws `ValidationError` on failure (not ZodError)

### errorHandler(err, req, res, next)
- Global Express error handler
- Catches `AppError` subclasses, returns consistent JSON
- Uses `err.errorCode` (not `err.code`)
- Non-operational errors log full stack in development

### authenticate(req, res, next)
- JWT verification from `Authorization: Bearer <token>`
- Access token TTL: 1 hour (hardcoded)
- Attaches `req.user = { id: string, roles: string[], email: string }`
- Throws `UnauthorizedError` if missing/invalid

### fraud(req, res, next)
- Runs on hold/purchase requests
- Checks velocity, bulk limits, payment retry patterns
- Throws `ForbiddenError` if blocked
- All fraud data stored in Redis (ephemeral)

### idempotency(req, res, next)
- Redis-based idempotency keys
- Reads `X-Idempotency-Key` header
- Returns cached response if replay detected

## WebSocket

Separate from HTTP server in `src/ws/index.ts`.
- Upgrades on the same port as HTTP
- Broadcasts seat status changes to connected clients
- Room-based: clients subscribe to event-specific rooms

## Docker

- **Dev:** `docker-compose.dev.yml` — Postgres 16 + Redis 7 only
- **Prod:** `docker-compose.yml` — full stack (app + Postgres + Redis)
- Container names prefixed `ticketer-`
- Single-stage Dockerfile, `EXPOSE 8810`

**Commands:**
```bash
npm run docker:up          # Start dev DBs
npm run docker:down        # Stop dev DBs (removes volumes)
npm run docker:prod:up     # Start production stack
npm run db:migrate         # Create migration (dev)
npm run db:migrate:deploy  # Apply migrations (prod)
```

## Prisma

- 10 models, UUID primary keys (`@db.Uuid`), Timestamptz timestamps
- Money fields: `Decimal(10, 2)`
- Enums for all status fields
- Indexes on foreign keys and frequently-queried columns
- Unique constraints: `[eventId, label]` on Seat, `idempotencyKey` on Order/Refund/Transfer, `token` on RefreshToken
- User model uses `roles UserRole[]` (PostgreSQL array) — users can be both organizer and buyer

## Validation

Centralized Zod schemas in `src/validation/`.
- One file per resource: `auth.ts`, `events.ts`, `seats.ts`, `orders.ts`, etc.
- Export named schemas: `registerSchema`, `loginSchema`, `createEventSchema`, etc.
- Route files import from `src/validation/`

## Coding Conventions

- No semicolons
- Single quotes
- Trailing commas everywhere
- 100 char print width, 2 space indent
- ESM imports (no `require`)
- Positional constructor args (no options objects)
- No factory functions, no `toJSON()` on errors
- Services contain business logic, controllers handle HTTP
- Barrel exports via `index.ts` in errors/ and validation/

## Route Structure

Flat — one file per resource in `src/routes/`:
```
src/routes/auth.ts
src/routes/events.ts
src/routes/seats.ts
src/routes/orders.ts
src/routes/refunds.ts
src/routes/resale.ts
src/routes/transfers.ts
src/routes/health.ts
```

## Auth

- JWT with `HS256` signing
- Access token: 1 hour TTL (hardcoded), signed with `JWT_SECRET`
- Refresh token: 7 day TTL (hardcoded), signed with `JWT_REFRESH_SECRET`
- Refresh token rotation: each refresh invalidates old token, issues new pair
- Token payload: `{ sub: userId, roles: string[], email: string }`
- `req.user` typed as `{ id: string; roles: string[]; email: string }`
- Routes use `authenticate` middleware, then check `req.user.roles` for authorization
- Password requirements: 8+ chars, 1 uppercase, 1 lowercase, 1 digit, 1 special character

### Auth Routes

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/auth/register` | No | Create account with initial role → token pair |
| POST | `/auth/login` | No | Verify credentials → token pair |
| POST | `/auth/refresh` | No | Rotate refresh token → new pair |
| POST | `/auth/logout-all` | Yes | Delete all refresh tokens for user |
| PATCH | `/auth/roles` | Yes | Add a role (e.g., buyer → organizer) |

### Auth Flow

1. Register — hash password, create user, generate tokens, store refresh in DB, return both
2. Login — verify credentials, generate tokens, return both
3. Refresh — look up refresh token in DB, check expiry, delete old (rotation), generate new pair
4. Logout-all — delete all refresh tokens for user from DB
5. Authenticated requests — middleware decodes JWT, checks signature + expiry, attaches `req.user`

## User Roles

Two actors with different journeys:

### Organizer
Register → Create Event → Add Seats → Manage Bookings → View Sales → Process Refunds

**Access:** Event CRUD, seat management, order management (own events), refund processing, sales analytics

### Buyer
Browse anonymously → Select Seats → Register/Login → Hold Seats → Pay → View Tickets → Request Refund → Resell/Transfer

**Access:** Browse events (public), hold seats, complete payment, view own orders, request refund, resell/transfer

### Role Management
- Users select initial role at registration (`organizer` or `buyer`)
- Users can add the other role later via `PATCH /auth/roles`
- A single account can have both roles

## Fraud Detection

Rule-based fraud detection (no ML). Runs as middleware on hold/purchase requests.

### Rules

| Rule | Trigger | Action | Config |
|------|---------|--------|--------|
| Velocity | >N holds from same user in X min | Block | `FRAUD_MAX_HOLDS=10`, `FRAUD_HOLD_WINDOW_MIN=10` |
| Bulk limit | User buying >N seats per event | Block | `FRAUD_MAX_SEATS_PER_EVENT=8` |
| Bot detection | Request interval <X ms | Flag (log) | `FRAUD_MIN_REQUEST_INTERVAL_MS=500` |
| Payment retry | >N failed payments in X min | Block | `FRAUD_MAX_FAILED_PAYMENTS=5`, `FRAUD_PAYMENT_WINDOW_MIN=15` |

### Implementation
- `src/service/fraudService.ts` — `checkHold()`, `checkPurchase()`
- `src/middleware/fraud.ts` — middleware that calls fraudService
- All fraud data in Redis (ephemeral, no Prisma models needed)

### Integration
```
POST /holds → auth middleware → fraud middleware → hold service
POST /orders → auth middleware → fraud middleware → order service
```

## Resale Price Suggestion

Heuristic-based pricing (no ML). Returns suggested price when creating resale listings.

### Algorithm
```
suggestedPrice = faceValue * demandMultiplier * timeMultiplier * comparableMultiplier

Constraints:
  minPrice = faceValue * 0.8   (prevent deep discounting)
  maxPrice = faceValue * 2.0   (prevent gouging)
```

### Multipliers

| Factor | Logic |
|--------|-------|
| demandMultiplier | Views/holds ratio on event. Low = 1.0, high = 1.5 |
| timeMultiplier | Time to event. Far out = 1.0, close (<48h) = 1.3 |
| comparableMultiplier | Compare to other resale listings. No data = 1.0 |

### Implementation
- `src/service/resalePricingService.ts` — `suggestPrice()`
- Returns `{ suggestedPrice, factors }` for transparency
- Called when creating resale listing; seller can accept or set own price

## Known Issues to Fix

1. **`.gitignore`** — `.env*` too broad (excludes `.env.example`), `*md` excludes markdown, `.dockerignore` excluded
2. **`@types/jest`** — v30 incompatible with ts-jest v29; downgrade to `^29.5.14`

## Phase Plan

### Phase 1: Scaffold + Auth (in progress)
- Bug fixes (errorHandler, UnauthorizedError, HoldExpiredError)
- Schema change (role → roles array) + config changes
- RefreshToken repository
- Auth service + JWT helpers
- Auth middleware
- Validation schemas
- Auth routes
- Wire into app.ts

### Phase 2: Core Services + Fraud Detection
- Event service (organizer CRUD)
- Seat service (create, update, bulk create)
- Hold system (Redis TTL + Prisma transactions)
- Order + Paystack payment flow
- Fraud detection (rule-based middleware)

### Phase 3: Business Logic + Resale Pricing
- Auto-refund window (BullMQ delayed jobs)
- Resale marketplace
- Resale price suggestion (heuristic)
- Seat transfers
- WebSocket broadcasts
- Notification system (Postmark)

### Phase 4: Testing
- Unit tests per service
- Integration tests with Testcontainers
- k6 load tests for concurrent holds
- Contract tests (Dredd or similar, deferred)

### Phase 5: Production
- OpenAPI spec generation (shelved)
- Graceful shutdown (Prisma disconnect, Redis disconnect, BullMQ close)
- Health check endpoint (already basic)
- Monitoring/logging
