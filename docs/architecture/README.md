# Architecture

## Principles

1. **Profile is the primary isolation boundary.**
2. **Browser state, network identity, and device identity are separate domains.**
3. **No hidden global mutable state may silently cross Profiles.**
4. **A proxy is a transport service, not a fingerprint feature.**
5. **Device profiles describe coherent combinations of values; they are not arbitrary randomizers.**
6. **Upstream changes are imported deliberately and recorded.**
7. **Every security-sensitive feature gets an acceptance test before release.**

## Documents

| Document | Purpose |
|---|---|
| `v0.1-baseline.md` | Frozen scope and architecture boundaries |
| `profile-model.md` | Profile schema, lifecycle, isolation |
| `networking.md` | Proxy, SSH, TUN/VPN and leak boundaries |

## Dependency direction

```text
UI
 ↓
Profile Application Service
 ↓
Profile Store ───── Device Profile Store
 ↓
Browser Runtime Adapter
 ↓
Gecko / WebLibre upstream

Network Service
 ├─ Proxy abstraction
 ├─ SSH tunnel adapter
 └─ TUN/VPN adapter
```

The browser runtime must not own SSH credentials, and the UI must not directly manipulate browser storage paths.
