# Networking Architecture

## Goal

Allow each Profile to reference an independent logical network route without coupling browser state to tunnel implementation.

## Route model

```text
NetworkRoute
├── route_id
├── type: DIRECT | HTTP | SOCKS5 | SSH_TUNNEL | VPN_TUNNEL
├── endpoint_ref
├── dns_policy
├── ipv6_policy
├── webrtc_policy
└── health_policy
```

## SSH design

The planned SSH mode is **SSH local dynamic forwarding (`-D`) to a local SOCKS5 endpoint**, managed by an Android-native tunnel service. The application should use a maintained SSH library rather than implementing the SSH protocol itself.

```text
Profile
  ↓
NetworkRoute(SSH_TUNNEL)
  ↓
SSH Tunnel Service
  ↓
local SOCKS5 endpoint
  ↓
proxy/TUN adapter
  ↓
browser traffic
```

The browser must not receive or persist the SSH private key. The tunnel service owns the credential reference and lifecycle.

## Important boundary

A browser-level proxy setting does not automatically prove that every network request is routed through the proxy. Future acceptance tests must explicitly cover:

- DNS resolution;
- HTTP/HTTPS requests;
- IPv4/IPv6;
- WebRTC candidates;
- redirects and downloads;
- extension traffic where supported;
- background browser services.

## TUN/VPN

If engine-level proxy routing cannot guarantee complete per-Profile routing, a later implementation may use Android `VpnService` and a maintained TUN-to-proxy component. TUN routing is a system-level mechanism and must not be enabled implicitly without clear user consent.

## Failure policy

Default for a configured non-direct route:

**fail closed** when the user explicitly requests leak protection.

That means a dead SSH/proxy route must not silently fall back to the device's direct network. A separate user-visible option may allow fail-open for ordinary privacy use cases.

## Observability

Expose only non-secret health information:

- route state;
- tunnel connected/disconnected;
- last successful connection time;
- latency class;
- byte counters if available.

Never log private keys, passwords, proxy credentials, authentication headers, cookies, or full URLs containing sensitive query data.
