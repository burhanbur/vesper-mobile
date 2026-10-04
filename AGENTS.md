# AGENTS.md

## Project

Personal & Household Finance mobile app.

## Tech Stack

* Flutter + Dart
* Riverpod — state management
* go_router — routing
* Drift + SQLite — local database / offline-first
* Dio — REST API
* flutter_secure_storage — auth token storage
* uuid — client-generated UUID
* connectivity_plus — connectivity/sync trigger
* Freezed + json_serializable — models/JSON
* build_runner — code generation
* fl_chart — charts

## Architecture

Use feature-first structure:

```text
lib/
├── app/
├── core/
├── database/
└── features/
    ├── auth/
    ├── household/
    ├── accounts/
    ├── categories/
    ├── transactions/
    ├── investments/
    ├── reports/
    └── sync/
```

Use:

```text
UI → Riverpod → Repository → Local/Remote Data Source
```

Do not put business logic, database queries, or API calls directly inside widgets.

## Offline-first

Local SQLite/Drift is the primary data source for the mobile app.

For user mutations:

```text
User Action
→ Local DB
→ Sync Queue
→ Background Sync
→ Express API
→ PostgreSQL
```

Always save financial data locally first.

Do not make the UI depend on a successful API request to save data.

Use client-generated UUIDs for syncable entities.

Use soft delete/tombstones for syncable data.

Sync must support:

* retry;
* incremental pull/cursor;
* server version;
* idempotent requests;
* basic conflict handling.

Connectivity status is only a trigger for sync, not proof that the API is reachable.

## Backend

The mobile app communicates with:

```text
Flutter
  ↓
Express.js API
  ↓
PostgreSQL
  +
Redis
```

PostgreSQL is the shared source of truth.

Redis is only for supporting concerns such as cache/session/rate limiting. Never use Redis as the primary financial database.

## Finance Rules

Core entities:

* User
* Household
* Account
* Category
* Transaction
* Investment
* Investment Transaction

Transaction types:

```text
INCOME
EXPENSE
TRANSFER
INVESTMENT_BUY
INVESTMENT_SELL
```

Transfers are not income or expense.

Investment buy/sell must correctly affect both cash balance and investment position.

Do not use floating point for money calculations.

## Coding Rules

* Prefer simple solutions over unnecessary abstractions.
* Reuse existing project patterns before introducing new ones.
* Do not add dependencies without a clear reason.
* Do not introduce microservices, CQRS, or event sourcing.
* Keep changes focused on the requested feature.
* Add/update tests for meaningful business logic or behavior changes.
* Do not manually edit generated `.g.dart` / `.freezed.dart` files.

## Validation

Before finishing a change:

```bash
flutter analyze
flutter test
```

Run code generation when required:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Important

When requirements are unclear, inspect the existing code and follow the established project conventions.

Do not silently change business rules or data models.
