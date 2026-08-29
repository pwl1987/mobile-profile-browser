# Profile Model

## Identity

A Profile has a stable random `profile_id`. Display names are mutable and are never used as storage identifiers.

```text
Profile
├── profile_id
├── name
├── created_at
├── updated_at
├── browser_state_ref
├── device_profile_id
├── network_route_id
├── status
└── schema_version
```

## Lifecycle

```text
CREATED → STARTING → ACTIVE → STOPPING → STOPPED
                       │
                       └────────────→ ERROR
```

Only one lifecycle owner may mutate a Profile runtime at a time. State transitions must be idempotent.

## Isolation contract

A Profile must have an explicit ownership mapping for every persistent datum. Data is either:

- `PROFILE`: owned by one Profile;
- `APP_GLOBAL`: intentionally shared by the application;
- `EPHEMERAL`: runtime-only and discarded;
- `SECRET`: encrypted and separately protected.

Cookies, site storage, browsing sessions and permissions are `PROFILE` unless an upstream engine primitive makes a narrower boundary necessary and the exception is documented.

## Concurrency

V0.1 should support one active browser runtime at a time. The data model may support multiple Profiles, but simultaneous live Gecko runtimes are deferred until memory/CPU behavior is measured on target devices.

## Import/export

Import/export is deferred. When implemented, an export must carry a schema version and must not silently import secrets or global state.
