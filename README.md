# Mobile Profile Browser

> Android-first, local-first browser with isolated browsing profiles, per-profile network routing, and coherent device profiles.

**Status: V0.1 Architecture Baseline — implementation not started.**

This project is being developed as an independent product using [WebLibre](https://github.com/FaFre/WebLibre) as the upstream browser foundation. WebLibre is AGPL-3.0 licensed; derivative distribution must preserve the applicable license and source obligations.

## Product goal

A single Android device should be able to run multiple long-lived browser Profiles with strict separation of browser state and independently configured network paths:

```text
Android APK
  └─ Profile Manager
      ├─ Profile A
      │   ├─ Gecko/browser state
      │   ├─ cookies + storage
      │   ├─ device profile
      │   └─ proxy / tunnel
      ├─ Profile B
      └─ Profile C
```

## V0.1 scope

- Establish a reproducible WebLibre upstream baseline.
- Define the Profile data model and lifecycle.
- Define storage isolation boundaries.
- Define proxy abstraction without coupling the browser to a specific tunnel implementation.
- Define the SSH → SOCKS5 architecture for a later milestone.
- Define a device-profile model that keeps related browser-visible values internally consistent.
- Add architecture, security, testing, and contribution guardrails before feature work.

## Planned milestones

| Milestone | Goal | Status |
|---|---|---|
| V0.1 | Baseline + profile architecture | Planned |
| V0.2 | Per-profile proxy routing | Planned |
| V0.3 | SSH tunnel integration | Planned |
| V0.4 | Device-profile management | Planned |
| V0.5 | Network/privacy leak validation | Planned |
| V0.6 | Fingerprint consistency engine | Planned |
| V0.7+ | Backup, import/export, automation | Planned |

## Architecture documents

- `docs/architecture/README.md` — architecture index and decision rules
- `docs/architecture/v0.1-baseline.md` — V0.1 frozen boundaries
- `docs/architecture/profile-model.md` — Profile lifecycle and isolation contract
- `docs/architecture/networking.md` — proxy and SSH/TUN design
- `docs/security/threat-model.md` — security assumptions and non-goals
- `docs/testing/acceptance-matrix.md` — acceptance gates

## Upstream

Primary upstream: [FaFre/WebLibre](https://github.com/FaFre/WebLibre)

The upstream repository currently describes WebLibre as an Android Gecko-based browser with Profiles, isolated browsing, cookie isolation, and multi-protocol proxy capabilities. Its current workspace is Dart/Flutter based. These capabilities are inputs to our architecture, not a guarantee that every requirement here is already implemented.

## Development rule

Do not implement fingerprint spoofing by a collection of ad-hoc JavaScript overrides. Any device profile must be internally coherent and must be validated against the actual browser/engine capabilities. Network identity and browser identity are separate layers.

## License

Project licensing will be finalized before the first derivative code import. Because the planned implementation derives from an AGPL-3.0 upstream, do not add a permissive license header that conflicts with upstream obligations.
