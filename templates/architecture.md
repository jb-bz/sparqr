# Architecture: <feature or system name>

> Stage 4 of SPARC+Design. Turns the pseudocode into a system design.

## Components

> One paragraph per component: what it owns, what its public interface is, what it does NOT do.

### Component 1: <name — e.g. "Auth Service">
- **Owns**: <e.g. user sessions, refresh tokens, OAuth state>
- **Public interface**: <e.g. `POST /auth/login`, `POST /auth/refresh`, `GET /auth/me`>
- **Does NOT**: <e.g. own user data, own billing>
- **Deploys as**: <e.g. single FastAPI process, in-process with the main app>
- **Persistence**: <e.g. Redis for sessions, Postgres for refresh tokens>

### Component 2: <name>
- **Owns**: …
- **Public interface**: …
- **Does NOT**: …
- **Deploys as**: …
- **Persistence**: …

### Component 3: <name>
- …

## Data Flow

> For each major user-facing operation, describe the data flow end-to-end.

### Flow 1: <operation — e.g. "User signs up">
1. Client → POST /api/auth/signup with {email, password}
2. Auth Service → validate input format
3. Auth Service → check email is not already in use (User Store)
4. Auth Service → hash password (Argon2id)
5. Auth Service → create user (User Store)
6. Auth Service → create session, return access + refresh tokens
7. Client → store tokens, redirect to /onboarding

### Flow 2: <operation>
…

## API Contracts

> Exact request/response shapes. The Refinement stage will implement to these.

### Endpoint 1: `POST /api/auth/signup`

**Request:**
```json
{
  "email": "user@example.com",
  "password": "<plaintext, min 12 chars>"
}
```

**Response 201:**
```json
{
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "created_at": "ISO-8601"
  },
  "access_token": "jwt",
  "refresh_token": "jwt",
  "expires_in": 3600
}
```

**Response 400 (validation):**
```json
{ "error": "validation_failed", "fields": { "email": "invalid", "password": "too short" } }
```

**Response 409 (conflict):**
```json
{ "error": "email_in_use" }
```

### Endpoint 2: …
…

## Data Models

### Table: `users`
| column | type | constraints | notes |
|---|---|---|---|
| id | uuid | PK | |
| email | text | UNIQUE NOT NULL | |
| password_hash | text | NOT NULL | argon2id |
| created_at | timestamptz | NOT NULL DEFAULT now() | |
| updated_at | timestamptz | NOT NULL DEFAULT now() | |

### Table: `sessions`
| column | type | constraints | notes |
|---|---|---|---|
| id | uuid | PK | |
| user_id | uuid | FK → users.id | |
| refresh_token_hash | text | NOT NULL | |
| expires_at | timestamptz | NOT NULL | |
| created_at | timestamptz | NOT NULL DEFAULT now() | |

## Technology Choices

> For each: what we picked, what we rejected, why.

### Choice 1: <e.g. "Web framework: FastAPI">
- **Picked**: FastAPI
- **Rejected**: Flask (no async), Django (too heavy for this scope)
- **Rationale**: Async-first, Pydantic validation out of the box, type hints align with our style

### Choice 2: <e.g. "Database: Postgres">
- **Picked**: Postgres
- **Rejected**: SQLite (no concurrent writers), MongoDB (we need ACID for auth)
- **Rationale**: ACID guarantees matter for user data; we already have it in our stack

### Choice 3: <e.g. "Auth: JWT vs session cookies">
- **Picked**: JWT (access) + refresh token in HttpOnly cookie
- **Rationale**: API-first; cookies work for web; JWT allows mobile clients later

## Failure Modes

> For each component: how does it fail, and what recovers.

| Component | Failure mode | Detection | Recovery |
|---|---|---|---|
| Auth Service | DB unreachable | health check fails | return 503, no state change |
| Auth Service | Argon2 takes too long | timeout (5s) | return 500, log |
| User Store | Unique constraint violation | caught at insert | return 409 email_in_use |
| Session store | Token expired | JWT exp claim | client refreshes |

## Security Considerations

- **Input validation**: Pydantic models on all endpoints, no raw dicts
- **Auth**: Argon2id for passwords, short-lived JWTs (1h), refresh tokens rotated on use
- **Rate limiting**: per-IP and per-account, on /auth/* endpoints specifically
- **CSRF**: not applicable (JWT in Authorization header, not cookies for API; web uses HttpOnly cookies + SameSite=Strict)
- **Injection**: parameterized queries only; ORM with named binds
- **Secrets**: env vars only; never in code; never logged

## Performance Budgets

- **p50 latency for /auth/login**: < 100ms (excluding Argon2)
- **p95 latency for /auth/login**: < 500ms (Argon2 dominates)
- **p95 latency for /auth/me**: < 50ms
- **Throughput target**: 100 logins/sec on a single instance

## Open Architecture Questions

- <anything still TBD before refinement>
