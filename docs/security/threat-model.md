# Threat Model

## Assets

- Profile cookies and site data
- Saved credentials and browser permissions
- SSH/proxy credentials
- Profile metadata
- Device-profile configuration

## Threats

1. Cross-profile data leakage.
2. Direct-network fallback when a protected route fails.
3. Credential disclosure through logs/backups/crash reports.
4. Corruption of the active-profile registry.
5. False assumptions that a browser-visible setting changes an underlying engine characteristic.
6. Upstream dependency changes that weaken isolation or security.

## Security requirements

- Secrets are stored through Android Keystore-backed protection.
- Profile storage boundaries are explicit and tested.
- Protected routes have a fail-closed mode.
- Debug logging is disabled or sanitized in release builds.
- Dependency and upstream changes are reviewed before release.
- Device-profile fields have an explicit capability state: controlled, derived, observed, or unsupported.

## Non-goals

This project does not promise anonymity, immunity from website detection, or that any particular anti-fingerprinting configuration defeats a site's risk engine. The product goal is controlled profile isolation and coherent privacy/network configuration.
