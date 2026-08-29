# V0.1 Acceptance Matrix

| ID | Area | Acceptance |
|---|---|---|
| P-01 | Profile | Create, rename, activate and delete a Profile |
| P-02 | Isolation | Cookies from A are absent in B |
| P-03 | Isolation | LocalStorage/IndexedDB from A are absent in B |
| P-04 | Isolation | Permissions do not unintentionally cross Profiles |
| P-05 | Lifecycle | Repeated start/stop/switch is idempotent |
| P-06 | Recovery | Crash during switch leaves one valid active-profile state |
| N-01 | Network | Direct route is explicitly distinguishable from proxied route |
| N-02 | Network | Protected route does not silently fall back to direct traffic |
| N-03 | Network | DNS/IPv6/WebRTC behavior is documented and tested before claiming leak resistance |
| S-01 | Secrets | SSH credentials never appear in ordinary logs |
| S-02 | Secrets | Sensitive credentials are Keystore protected |
| D-01 | Device | Device-profile schema validates incompatible values |
| D-02 | Device | Unsupported engine controls are reported as unsupported, not spoofed |
| U-01 | Upstream | Exact WebLibre baseline commit is recorded |
| U-02 | Build | Clean checkout can reproduce a debug APK |

## Release rule

No feature is marked complete solely because the UI exists. It needs a test or a documented engine limitation and an explicit acceptance result.
