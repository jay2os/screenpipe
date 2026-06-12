## Work Insights Supabase Plan

### Scope

This plan replaces the earlier Azure-first control-plane direction for the near term.

Current decision:

- Use Supabase Auth for user identity.
- Use Supabase Postgres for all application SQL and metadata.
- Defer Azure-only control-plane concerns until later enterprise requirements justify them.
- Prioritize organization onboarding and user-to-organization mapping first.
- After `org_id` and `user_id` are stable, build device identity and ingestion auth on top.

### Goals

- Establish a stable identity model for organizations, users, and devices.
- Support an onboarding path where users are attached to an organization before ingestion starts.
- Keep the first implementation simple enough to ship quickly.
- Preserve a migration path later if the control plane moves off Supabase.

### Non-Goals

- Enterprise SSO.
- Per-tenant isolated databases.
- Full Azure migration plan.
- Final device-auth implementation details beyond the first production-safe shape.

### Core Decisions

#### 1. Supabase Auth is the identity source

Supabase Auth owns login, signup, session refresh, and primary user identity.

Application code should treat the Supabase Auth user id as the canonical external identity:

- `supabase_user_id`

The application should still maintain its own application-facing user row so product state does not depend on querying `auth.users` directly for normal flows.

#### 2. Supabase Postgres is the source of truth for app state

All current cloud SQL and future work-insights metadata should live in Supabase Postgres for now.

That includes:

- organizations
- application users / profiles
- organization membership
- devices
- sync batches
- content atoms
- input signals
- reports

#### 3. Onboarding happens before ingestion

Before device uploads are trusted, the system must know:

- `org_id`
- `user_id`

The first implementation should not try to solve device identity before organization and user identity are stable.

#### 4. Device identity is separate from user auth

User auth proves who the user is.
Device auth proves that a specific installed client is allowed to upload on behalf of that user and org.

The ingestion path should eventually use a device-scoped credential, not a long-lived Supabase user session token.

### Proposed Data Model

These names can change during implementation, but the shape should remain.

#### `organizations`

- `id uuid primary key`
- `name text not null`
- `slug text unique`
- `allowed_email_domains text[] null`
- `created_at timestamptz not null default now()`
- `created_by uuid null references app_users(id)`

#### `app_users`

- `id uuid primary key`
- `supabase_user_id uuid not null unique`
- `email text not null`
- `display_name text null`
- `created_at timestamptz not null default now()`
- `last_seen_at timestamptz null`

Notes:

- This row mirrors the Supabase-authenticated user into app state.
- `supabase_user_id` links back to Supabase Auth.

#### `organization_members`

- `org_id uuid not null references organizations(id)`
- `user_id uuid not null references app_users(id)`
- `role text not null`
- `status text not null`
- `joined_at timestamptz not null default now()`
- `invited_by uuid null references app_users(id)`
- `primary key (org_id, user_id)`

Suggested initial role values:

- `owner`
- `admin`
- `member`

Suggested initial status values:

- `active`
- `invited`
- `disabled`

#### `devices`

- `id uuid primary key`
- `org_id uuid not null references organizations(id)`
- `user_id uuid not null references app_users(id)`
- `device_label text not null`
- `platform text null`
- `token_hash text not null`
- `revoked_at timestamptz null`
- `last_seen_at timestamptz null`
- `created_at timestamptz not null default now()`

#### Work-insights tables

Every important work-insights table should include `org_id`.

Tables associated with a specific human should also include `user_id`.

Tables associated with ingestion provenance should also include `device_id`.

Examples:

- `sync_batches`
- `content_atoms`
- `input_signals`
- `timeline_segments`
- `segment_reports`
- `user_reports`

### Onboarding Models

We need one onboarding flow for organizations, with user onboarding derived from that organization.

Two acceptable first-pass models exist.

#### Option A: Manual organization creation

Flow:

1. Admin signs up.
2. We manually create the organization row.
3. We manually attach the first user to that organization as `owner`.
4. Additional users are allowed only after manual membership creation or invitation.

Pros:

- Fastest to ship.
- Lowest ambiguity.
- Good for early pilots.

Cons:

- High manual ops burden.
- No self-serve team expansion.

#### Option B: Domain-based organization assignment

Flow:

1. User signs up with Supabase Auth.
2. Backend reads the verified email address.
3. Backend matches the email domain against `organizations.allowed_email_domains`.
4. If exactly one match exists, create `organization_members` automatically.
5. If no match exists, user is blocked pending manual approval or org creation.

Pros:

- Good balance between speed and self-serve.
- Simple for company-owned domains.

Cons:

- Weak for contractors, subsidiaries, and shared email providers.
- Needs careful handling when multiple orgs could claim the same domain.

### Recommended First Release

Use a hybrid:

- Start with manual organization creation.
- Support optional domain-based auto-join for approved domains.
- Do not allow arbitrary self-created organizations yet.

This keeps onboarding operationally simple while avoiding hard-coding every user by hand.

Final v1 policy:

- Each user belongs to exactly one organization.
- Organization assignment uses trusted email-domain matching.
- Approved company domains are trusted for auto-join.
- Pending memberships can exist before activation.
- Organization ownership is assigned manually, never inferred from email domain alone.

### Identity Flow

#### Signup / login

1. User signs in with Supabase Auth.
2. Frontend sends the Supabase JWT to the backend.
3. Backend verifies the JWT.
4. Backend reads:
   - Supabase user id
   - email
   - email verification state
5. Backend upserts `app_users`.
6. Backend resolves organization membership.
7. Backend returns the resolved application identity:
   - `user_id`
   - `org_id`
   - role
   - membership status

#### Organization resolution

Organization resolution order:

1. Existing active `organization_members` row.
2. Domain-based auto-join, if configured.
3. Manual pending state.

If no organization is resolved, ingestion must not be enabled.

Because v1 is single-org-per-user, backend identity resolution should return exactly one active `org_id` for each onboarded user.

### Device Identity and Auth

This comes after onboarding is working.

#### Device registration flow

1. Authenticated user calls `POST /devices/register`.
2. Backend verifies Supabase JWT.
3. Backend checks active membership for the selected or resolved org.
4. Backend creates a `devices` row.
5. Backend generates a long-lived device token.
6. Backend stores only `token_hash`.
7. Backend returns the raw device token once.

#### Ingestion auth flow

1. Desktop uploader sends the device token.
2. Backend resolves:
   - `device_id`
   - `org_id`
   - `user_id`
3. Backend accepts uploads only for active, non-revoked devices.
4. All persisted ingest metadata is stamped with `org_id`, `user_id`, and `device_id`.

Why:

- User session auth is appropriate for login and device registration.
- Device auth is appropriate for continuous background ingestion.

### API Plan

#### Phase 1: identity and onboarding

- `POST /auth/session/exchange`
  - Verify Supabase JWT.
  - Upsert `app_users`.
  - Resolve organization membership.
  - Return app identity.

- `GET /me`
  - Return current app identity, memberships, and onboarding state.

- `POST /organizations/:org_id/invitations` or manual admin tooling later
  - Optional in first pass.

#### Phase 2: device identity

- `POST /devices/register`
- `GET /devices`
- `POST /devices/:device_id/revoke`

#### Phase 3: ingestion

- `POST /ingest/upload-ticket`
- `PUT /ingest/uploads/:batch_id`
- `POST /ingest/upload-complete`

### RLS Strategy

Use Supabase RLS where it adds clear value, but do not force every backend path through end-user RLS immediately.

Recommended approach:

- Dashboard and direct user-facing queries can use RLS-friendly tables and policies.
- Backend ingestion and report generation can use trusted server credentials while still enforcing org and user checks in application code.

This avoids overcomplicating the first release while preserving a path to stronger policy enforcement later.

### Migration of Existing Cloud SQL

Current work-insights SQL should be moved into Supabase-managed migrations.

Migration principles:

- Add `org_id` to every relevant table.
- Normalize `user_id` to reference `app_users(id)`, not raw auth ids in every table.
- Keep `supabase_user_id` in `app_users`.
- Keep ingestion provenance explicit with `device_id`.

### Implementation Order

#### Stage 1: decide onboarding policy

- Single organization per user.
- Domain-based auto-join.
- Trusted approved company domains.
- Pending memberships allowed.
- Ownership assigned manually.

#### Stage 2: add Supabase-backed identity schema

- Create `app_users`
- Create `organizations`
- Create `organization_members`
- Add initial org bootstrap path

#### Stage 3: wire backend auth

- Verify Supabase JWTs in backend routes
- Add identity resolution endpoint
- Gate all work-insights access on resolved membership

#### Stage 4: adapt existing SQL

- Move current work-insights tables into Supabase migrations
- Add `org_id`, `user_id`, `device_id` columns where required
- Update code paths to use new ids

#### Stage 5: device auth

- Create `devices`
- Add device registration endpoint
- Issue hashed long-lived device tokens

#### Stage 6: ingestion auth conversion

- Stop relying on shared ingest tokens
- Require valid device credentials for upload flows
- Stamp ingest records with `org_id`, `user_id`, `device_id`

### Finalized v1 Policy

These decisions are fixed for the first implementation.

1. A user belongs to a single organization only.
2. Organization assignment uses domain-based auto-join.
3. Approved `@company.com` domains are trusted for automatic membership creation.
4. Pending and invited memberships are supported.
5. Ownership is always assigned manually.

Operational consequences:

- `organization_members` should enforce one active org membership per user in v1.
- Domain matching must be deterministic and reject ambiguous matches.
- Auto-join should create a `member` role by default, never `owner`.
- Manual admin action is required to assign or transfer ownership.
- Device registration must fail unless the user already has a resolved active membership.

### Immediate Next Step

Implement Stage 1 and Stage 2 first:

- finalize onboarding policy
- create identity tables
- add backend identity resolution

Only then start device registration and ingestion auth.
