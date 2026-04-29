# Myraba Fintech — Claude Code Context

## Project Overview
Myraba is a Nigerian fintech platform (think OPay/CashApp for Nigeria) built with:
- **Backend:** Spring Boot (Kotlin), PostgreSQL, JWT auth
- **Admin Frontend:** React + TypeScript + Tailwind CSS (in `/admin-frontend/`)
- **Mobile:** Flutter (in `/mobile/`)
- **Infrastructure:** Docker Compose (PostgreSQL only for now)

---

## Deployment

| Service        | Platform      | URL                                      | Notes                                      |
|----------------|---------------|------------------------------------------|--------------------------------------------|
| Backend        | Render (web)  | https://vingo-fintech.onrender.com       | Free tier — cold starts ~60s              |
| Admin Frontend | Render (static)| https://admin.myraba.com                | Must build with `VITE_API_URL=https://vingo-fintech.onrender.com` |
| Mobile         | Google Play   | Internal Testing track                   | Must build with `--dart-define=API_BASE_URL=https://vingo-fintech.onrender.com` |

**Critical build rules (never forget):**
- Every Flutter release build: `flutter build appbundle --release --dart-define=API_BASE_URL=https://vingo-fintech.onrender.com`
- Admin frontend must have `VITE_API_URL=https://vingo-fintech.onrender.com` set in Render's environment variables for the static site build
- Admin frontend also needs Render's SPA rewrite rule: `/* → /index.html (200)` so React Router works on direct URL access

---

## Current Mission
Continue improving and extending the platform — backend stability, admin panel features, and mobile app polish.

---

## Tech Stack

### Backend
- **Language:** Kotlin
- **Framework:** Spring Boot 3.x
- **Database:** PostgreSQL 16 (via Docker)
- **Auth:** JWT (stateless), BCrypt passwords, TOTP-based MFA
- **ORM:** Spring Data JPA / Hibernate (DDL auto: update)
- **Build:** Gradle (Kotlin DSL)
- **Base package:** `com.myraba.backend`

### Admin Frontend
- **Framework:** React 19 + TypeScript + Vite
- **Styling:** Tailwind CSS
- **Routing:** React Router DOM v7
- **Data fetching:** TanStack Query v5 + Axios
- **Charts:** Recharts
- **Icons:** Lucide React
- **Location:** `/admin-frontend/`
- **Dev server:** `npm run dev` (Vite, default port 5173)

### External APIs (all sandbox/dev keys)
| Service     | Purpose                        | Env Var Prefix        |
|-------------|--------------------------------|-----------------------|
| Resend      | Transactional email (OTP etc.) | `MYRABA_MAIL_*`       |
| Flutterwave | External gift payments         | `FLUTTERWAVE_*`       |
| VTpass      | Bill payments (airtime, data…) | `VTPASS_*`            |
| Dojah       | KYC (BVN/NIN verification)     | `DOJAH_*`             |

### Database
- **Connection:** `jdbc:postgresql://db:5432/myraba_db`
- **User/Pass:** `vingo` / `vingo2025`
- **Docker service name:** `db`

### JWT
- Secret: env var `JWT_SECRET` (dev fallback in `application.yml`)
- Expiry: 24 hours (env var `JWT_EXPIRATION`, ms)

### AES Encryption
- Key: env var `ENCRYPTION_KEY` (32-byte Base64) — used for sensitive field encryption

---

## Project Structure

```
Myraba-fintech/
├── backend/
│   ├── src/main/kotlin/com/myraba/backend/
│   │   ├── config/          # SecurityConfig, DataInitializer, CORS
│   │   ├── controller/      # REST controllers
│   │   │   └── admin/       # 15 admin controllers
│   │   ├── dto/             # Request/Response DTOs
│   │   ├── filter/          # JwtRequestFilter
│   │   ├── model/           # JPA entities
│   │   │   └── thrift/      # Thrift-specific entities
│   │   ├── repository/      # Spring Data repositories
│   │   │   └── thrift/
│   │   ├── scheduler/       # Cron jobs (thrift penalties, defaults)
│   │   ├── service/         # Business logic (17 services)
│   │   └── util/            # Helpers
│   ├── src/main/resources/
│   │   └── application.yml
│   ├── build.gradle.kts
│   └── Dockerfile
├── admin-frontend/          # React admin dashboard (BUILT)
│   ├── src/
│   │   ├── pages/           # 15 admin pages
│   │   ├── components/      # Layout, AuthGuard, StatCard
│   │   ├── context/         # AuthContext
│   │   ├── types/           # TypeScript types
│   │   └── lib/             # Utilities
│   └── package.json
├── mobile/                  # Flutter app
├── docker-compose.yml       # PostgreSQL only
└── CLAUDE.md                # This file
```

---

## Core Domain Models

| Entity                | Key Fields                                                                              |
|-----------------------|-----------------------------------------------------------------------------------------|
| `User`                | myrabaHandle, password, phone, email, accountNumber, customAccountId, role, status, kycStatus |
| `Wallet`              | balance (BigDecimal), one-to-one with User                                              |
| `Transaction`         | sender/receiverWallet (nullable), amount, type, status, description                     |
| `ThriftCategory`      | name, amount, frequency (DAILY/WEEKLY/MONTHLY), duration, memberCount                  |
| `ThriftMember`        | user, category, position, cyclesContributed, penaltyLevel                               |
| `PrivateThrift`       | creator, inviteCode, positionAssignment (RAFFLE/MANUAL), status                         |
| `GiftCategory`        | name, slug, active                                                                      |
| `GiftTransaction`     | sender (nullable), recipient, item, paymentMethod (WALLET/CARD), status                 |
| `KycSubmission`       | type (BVN/NIN), maskedNumber, status, verifiedName, dob                                 |
| `UserPoints`          | totalLifetime, thisYear, allTime                                                         |
| `BillPayment`         | category, serviceId, provider, identifier, amount, vtpassCode, status                  |
| `AuditLog`            | adminHandle, action, targetType, targetId, beforeValue, afterValue                      |
| `BroadcastMessage`    | title, body, type, audience, expiry                                                     |
| `Otp`                 | phone/email, code, purpose, expiresAt, used                                             |
| `MfaSecret`           | user, secret, enabled                                                                   |
| `IdempotencyRecord`   | idempotencyKey, responseBody, statusCode, createdAt                                     |
| `VingTagChangeRequest`| user, requestedHandle, status, reviewedBy                                               |

---

## User Roles & Permissions

| Role          | Access Level                                                    |
|---------------|-----------------------------------------------------------------|
| `USER`        | Standard app user                                               |
| `STAFF`       | Read-only admin (view users, transactions, audit)               |
| `ADMIN`       | Full admin except SUPER_ADMIN actions                           |
| `SUPER_ADMIN` | All access including balance adjustments, bulk points conversion |

---

## API Routes Summary

### Public / Auth
- `POST /auth/send-otp` — OTP for phone/email
- `POST /auth/login` — Login → JWT
- `POST /auth/register` — Register (verifies OTP)

### User (authenticated)
- `GET /api/users/me` — Own profile
- `GET /api/users/handle/{myrabaHandle}` — Look up by MyrabaTag
- `PUT /api/users/{id}` — Update profile
- `POST /api/users/me/tag-change` — Request MyrabaTag change
- `GET /api/users/me/qr` — Generate QR code PNG

### Wallet & Transfers
- `GET /wallets/{myrabaHandle}` — Public wallet info (for QR scanning)
- `GET /wallets/history` — Transaction history
- `POST /wallets/transfer` — Transfer by MyrabaTag
- `POST /wallets/transfer/account` — Transfer by 10-digit account number
- `POST /wallets/transfer/custom-id` — Transfer by custom account ID
- `POST /wallets/fund` — Fund wallet (admin/system)

### Thrift (Public)
- `GET /api/thrifts/categories` — Browse categories
- `POST /api/thrifts/categories/{id}/join` — Join thrift
- `POST /api/thrifts/me/contribute/{memberId}` — Record contribution
- `GET /api/thrifts/me` — My active thrifts

### Private Thrift
- `POST /api/private-thrifts` — Create thrift
- `POST /api/private-thrifts/join/{inviteCode}` — Request to join
- `POST /api/private-thrifts/{id}/contribute` — Contribute
- `POST /api/private-thrifts/{id}/payout/{memberId}` — Approve payout
- `POST /api/private-thrifts/{id}/eject/{memberId}` — Eject member

### Gifts
- `POST /api/gifts/send` — Send gift (wallet)
- `POST /api/gifts/balance/convert` — Convert gift balance → wallet
- `GET /api/gifts/categories` & `/items` — Catalog

### Bills
- `POST /api/bills/airtime`, `/data`, `/electricity`, `/cable`, `/betting`
- `GET /api/bills/history`

### KYC
- `POST /api/kyc/verify/bvn`, `/nin`
- `GET /api/kyc/status`

### Points
- `GET /api/points` — Balance
- `GET /api/points/history`

### MFA
- `POST /api/mfa/setup`, `/verify`, `/disable`

### Wrapped (Year in Review)
- `GET /api/wrapped` — User's year-in-review stats

### Admin (`/api/admin/**` — requires STAFF+)
- **Dashboard:** `GET /api/admin/dashboard/stats`
- **Users:** CRUD, role change, KYC update, freeze/suspend/activate
- **Staff:** Manage staff/admin accounts
- **Transactions:** List (filtered), single, reverse, audit trail
- **Reports:** Daily, monthly, date range, 30-day breakdown, all-time totals
- **Thrifts:** Create/manage public categories, view private thrifts, resolve defaults
- **Gifts:** Manage catalog, categories, items, prices
- **Points:** Grant, convert (single/bulk)
- **Broadcasts:** Create, list, deactivate
- **Audit Logs:** `GET /api/admin/audit` (filtered)
- **System:** Health, liquidity report, activate/deactivate thrift categories
- **Balance:** `POST /api/admin/balance/adjust` (SUPER_ADMIN only)
- **MyrabaTag Requests:** Approve/deny tag change requests
- **User Stats:** Per-user activity stats

---

## Known Issues / TODOs

### High Priority
1. **OTP SMS not implemented** — `SmsService` is a stub. Need Termii or AfricasTalking integration.
2. **Transfer race condition** — `WalletController` modifies balances without row-level locking (use `@Lock` or `SELECT FOR UPDATE`).

### Medium Priority
3. **CORS too permissive** — `allowedOriginPatterns = ["*"]` should be scoped to known domains in prod
4. **MyrabaTag validation** — No regex enforcement on allowed characters/length at registration
5. **Transaction type as String** — Prone to typos; should be an enum
6. **Error handling** — Many `IllegalArgumentException` throws not consistently translated to proper HTTP status codes

### Low Priority
7. **GiftBalance separate model** — Could be merged into Wallet for simplicity
8. **Missing SMS rate limiting on OTP**
9. **BigDecimal scale** — Some operations may need explicit scale for currency precision

---

## Admin Dashboard — Feature Status

### Overview / Dashboard
- [x] Total users, active users, transaction volume
- [x] System liquidity, pending KYC, failed transactions
- [x] Thrift pool value

### User Management
- [x] Search / filter users
- [x] User detail view (profile, wallet, transaction history, KYC)
- [x] Freeze / Suspend / Activate accounts
- [x] Update KYC status manually
- [x] Change user role
- [x] View/approve MyrabaTag change requests

### Transaction Management
- [x] List with filters (type, status, date range, amount range)
- [x] Transaction detail view
- [x] Reverse transactions

### Financial Reports
- [x] Daily/monthly summary
- [x] 30-day breakdown chart
- [x] All-time platform totals

### Thrift Management
- [x] Create / activate / deactivate public thrift categories
- [x] View all private thrifts
- [x] Resolve disputed defaults

### Gift Catalog Management
- [x] Create categories and items
- [x] Toggle active status
- [x] Update prices

### Points
- [x] Grant points to user
- [x] Trigger year-end conversion

### Broadcasts
- [x] Create targeted messages
- [x] View active broadcasts
- [x] Deactivate broadcasts

### Audit Log
- [x] Filter by admin, action type, date range

### System
- [x] Health status
- [x] Liquidity overview

### Balance (SUPER_ADMIN)
- [x] Manual balance adjustment

### KYC Queue
- [x] Review and approve/reject KYC submissions

### Staff Management
- [x] Create and manage STAFF/ADMIN accounts

---

## Development Workflow

### Run backend locally (with Docker DB)
```bash
# Start database
docker-compose up -d db

# Run backend
cd backend
./gradlew bootRun
```

### Run admin frontend
```bash
cd admin-frontend
npm install
npm run dev
# Opens at http://localhost:5173
# API base: http://localhost:8080
```

### Build Docker image
```bash
docker build -t myraba-backend ./backend
```

### Environment Variables (production)
| Variable           | Purpose                              |
|--------------------|--------------------------------------|
| `DATABASE_URL`     | PostgreSQL JDBC URL                  |
| `DATABASE_USER`    | DB username                          |
| `DATABASE_PASSWORD`| DB password                          |
| `JWT_SECRET`       | JWT signing secret (min 256-bit)     |
| `ENCRYPTION_KEY`   | AES-256 key (32-byte Base64)         |
| `MYRABA_MAIL_USERNAME` | Resend SMTP username (= "resend") |
| `MYRABA_MAIL_PASSWORD` | Resend API key                   |
| `FLUTTERWAVE_SECRET_KEY` | Flutterwave API key            |
| `VTPASS_API_KEY`   | VTpass API key                       |
| `DOJAH_APP_ID`     | Dojah App ID                         |
| `DOJAH_PRIVATE_KEY`| Dojah private key                    |
| `PORT`             | Server port (default 8080)           |

---

## Commit History
- `6456521` — feat: profile editing, password change, help & support, year in review
- `04b674b` — fix: transfer UX, logout lag, gift validation, invite code dialog, registration flow
- `d1795e5` — fix: use Spring Data findTop for OTP queries, avoid duplicate result error
- `a044e8a` — feat: switch to Resend HTTP API for email delivery
- `3983ff2` — feat: dev OTP lookup endpoint for SUPER_ADMIN testing
- `3295a5f` — feat: deploy-ready config — env vars for DB/secrets
- `c42aab7` — feat: wallet creation + fetch by handle + auto-create on user signup
- `0146ee9` — feat: user registration + fetch by handle with UserResponse DTO
- `0cc4bcb` — feat: hello API + Docker setup
- `6995257` — Initial commit
