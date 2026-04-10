# Myraba Fintech — Claude Code Context

## Project Overview
Myraba is a Nigerian fintech platform (think OPay/CashApp for Nigeria) built with:
- **Backend:** Spring Boot (Kotlin), PostgreSQL, JWT auth
- **Mobile:** Flutter (in `/mobile/`)
- **Infrastructure:** Docker Compose (PostgreSQL only for now)
- **No separate admin frontend yet** — admin panel needs to be built as a web dashboard

---

## Current Mission
**Improve and complete the admin backend + build an admin frontend dashboard** that conforms to conventions of modern fintechs like CashApp, OPay, PalmPay, and Kuda.

---

## Tech Stack

### Backend
- **Language:** Kotlin
- **Framework:** Spring Boot 3.x
- **Database:** PostgreSQL 16 (via Docker)
- **Auth:** JWT (stateless), BCrypt passwords
- **ORM:** Spring Data JPA / Hibernate (DDL auto: update)
- **Build:** Gradle (Kotlin DSL)
- **Base package:** `com.myraba.backend`

### External APIs (all sandbox/dev keys)
| Service     | Purpose                        | Env Var Prefix   |
|-------------|--------------------------------|------------------|
| Flutterwave | External gift payments         | `FLUTTERWAVE_*`  |
| VTpass      | Bill payments (airtime, data…) | `VTPASS_*`       |
| Dojah       | KYC (BVN/NIN verification)     | `DOJAH_*`        |
| Gmail SMTP  | OTP emails                     | `VINGO_MAIL_*`   |

### Database
- **Connection:** `jdbc:postgresql://db:5432/myraba_db`
- **User/Pass:** `myraba` / `myraba2025`
- **Docker service name:** `db`

### JWT
- Secret: `ThisIsAMyrabaFintechSuperSecretKeyForJWT2025` (dev only — use env var in prod)
- Expiry: 24 hours

---

## Project Structure

```
Myraba-fintech/
├── backend/
│   ├── src/main/kotlin/com/myraba/backend/
│   │   ├── config/          # SecurityConfig, DataInitializer, CORS
│   │   ├── controller/      # REST controllers
│   │   │   └── admin/       # 14 admin controllers
│   │   ├── dto/             # Request/Response DTOs
│   │   ├── filter/          # JwtRequestFilter
│   │   ├── model/           # JPA entities
│   │   │   └── thrift/      # Thrift-specific entities
│   │   ├── repository/      # Spring Data repositories
│   │   │   └── thrift/
│   │   ├── scheduler/       # Cron jobs (thrift penalties, defaults)
│   │   └── service/         # Business logic (11 services)
│   ├── src/main/resources/
│   │   └── application.yml
│   ├── build.gradle.kts
│   └── Dockerfile
├── mobile/                  # Flutter app
├── docker-compose.yml       # PostgreSQL only
└── CLAUDE.md                # This file
```

---

## Core Domain Models

| Entity              | Key Fields                                                                 |
|---------------------|----------------------------------------------------------------------------|
| `User`              | myrabaHandle, password, phone, email, accountNumber, customAccountId, role, status, kycStatus |
| `Wallet`            | balance (BigDecimal), one-to-one with User                                |
| `Transaction`       | sender/receiverWallet (nullable), amount, type, status, description       |
| `ThriftCategory`    | name, amount, frequency (DAILY/WEEKLY/MONTHLY), duration, memberCount     |
| `ThriftMember`      | user, category, position, cyclesContributed, penaltyLevel                 |
| `PrivateThrift`     | creator, inviteCode, positionAssignment (RAFFLE/MANUAL), status           |
| `GiftCategory`      | name, slug, active                                                         |
| `GiftItem`          | name, emoji, valueNaira, category, active                                 |
| `GiftTransaction`   | sender (nullable), recipient, item, paymentMethod (WALLET/CARD), status   |
| `KycSubmission`     | type (BVN/NIN), maskedNumber, status, verifiedName, dob                   |
| `UserPoints`        | totalLifetime, thisYear, allTime                                           |
| `BillPayment`       | category, serviceId, provider, identifier, amount, vtpassCode, status     |
| `AuditLog`          | adminHandle, action, targetType, targetId, beforeValue, afterValue        |
| `BroadcastMessage`  | title, body, type, audience, expiry                                        |
| `Otp`               | phone/email, code, purpose, expiresAt, used                               |

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

### Admin (`/api/admin/**` — requires STAFF+)
- **Dashboard:** `GET /api/admin/dashboard/stats`
- **Users:** CRUD, role change, KYC update, freeze/suspend/activate
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

---

## Known Issues / TODOs

### High Priority
1. **OTP SMS not implemented** — `OtpService` prints to console. Need Termii or AfricasTalking integration.
2. **Transfer race condition** — `WalletController` modifies balances without row-level locking (use `@Lock` or `SELECT FOR UPDATE`).
3. **No admin frontend** — All admin endpoints exist but no web dashboard UI yet.

### Medium Priority
4. **JWT secret must be env var in prod** — currently hardcoded in `application.yml`
5. **CORS too permissive** — `allowedOriginPatterns = ["*"]` should be scoped to known domains
6. **MyrabaTag validation** — No regex enforcement on allowed characters/length at registration
7. **Transaction type as String** — Prone to typos; should be an enum
8. **Error handling** — Many `IllegalArgumentException` throws not translated to proper HTTP status codes consistently

### Low Priority
9. **GiftBalance separate model** — Could be merged into Wallet for simplicity
10. **Missing SMS rate limiting on OTP**
11. **BigDecimal scale** — Some operations may need explicit scale for currency precision

---

## Admin Dashboard — Target Feature Set
Modelled after CashApp, OPay, Kuda, and PalmPay admin panels:

### Overview / Dashboard
- [ ] Total users (growth chart)
- [ ] Active users today / this week
- [ ] Total transaction volume (today / 7d / 30d)
- [ ] System liquidity (total wallet balances)
- [ ] Pending KYC count
- [ ] Failed transactions (24h)
- [ ] Thrift pool value locked

### User Management
- [ ] Search / filter users (name, MyrabaTag, phone, email, KYC status, account status)
- [ ] User detail view (profile, wallet balance, transaction history, KYC docs)
- [ ] Freeze / Suspend / Activate accounts
- [ ] Update KYC status manually
- [ ] Change user role
- [ ] View/approve MyrabaTag change requests

### Transaction Management
- [ ] List with filters (type, status, date range, amount range, user)
- [ ] Transaction detail view
- [ ] Reverse transactions (ADMIN+)
- [ ] Download CSV export

### Financial Reports
- [ ] Daily/monthly summary
- [ ] 30-day breakdown chart
- [ ] All-time platform totals

### Thrift Management
- [ ] Create / activate / deactivate public thrift categories
- [ ] View all private thrifts
- [ ] Resolve disputed defaults

### Gift Catalog Management
- [ ] Create categories and items
- [ ] Toggle active status
- [ ] Update prices

### Points
- [ ] Grant points to user
- [ ] Trigger year-end conversion

### Broadcasts
- [ ] Create targeted messages (by role/KYC status/all users)
- [ ] View active broadcasts
- [ ] Deactivate broadcasts

### Audit Log
- [ ] Filter by admin, action type, date range

### System
- [ ] Health status
- [ ] Liquidity overview

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

### Build Docker image
```bash
docker build -t myraba-backend ./backend
```

### Admin frontend (to be built)
Preferred stack: **React + TypeScript + Tailwind CSS + shadcn/ui**
Location: `/admin-frontend/` (to be created)
API base: `http://localhost:8080`

---

## Commit History
- `c42aab7` — wallet creation + fetch by myrabaHandle + auto-create on user signup
- `0146ee9` — user registration + fetch by myrabaHandle with UserResponse DTO
- `0cc4bcb` — hello API + Docker setup
- `6995257` — Initial commit
