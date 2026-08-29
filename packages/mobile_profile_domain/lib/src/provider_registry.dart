import 'mobile_profile.dart';

/// Provider 的静态注册信息。
final class NetworkProviderDescriptor {
  const NetworkProviderDescriptor({
    required this.kind,
    required this.name,
    required this.protocols,
    required this.capabilities,
  });

  final NetworkProviderKind kind;
  final String name;
  final Set<ProviderProtocol> protocols;
  final ProviderCapabilities capabilities;
}

/// 网络 Provider 注册表。
///
/// 这里只负责“能够支持什么”，不负责启动 runtime。真正的实现由上层
/// Adapter/Runtime 提供，因此 Domain 包不会依赖 sing-box、Android VPN 或 SSH。
final class NetworkProviderRegistry {
  NetworkProviderRegistry._();

  static const descriptors = <NetworkProviderKind, NetworkProviderDescriptor>{
    NetworkProviderKind.direct: NetworkProviderDescriptor(
      kind: NetworkProviderKind.direct,
      name: '直连',
      protocols: {ProviderProtocol.none},
      capabilities: ProviderCapabilities(tcp: true, ipv4: true, browserProxy: true),
    ),
    NetworkProviderKind.http: NetworkProviderDescriptor(
      kind: NetworkProviderKind.http,
      name: 'HTTP 代理',
      protocols: {ProviderProtocol.http},
      capabilities: ProviderCapabilities(tcp: true, ipv4: true, browserProxy: true),
    ),
    NetworkProviderKind.socks5: NetworkProviderDescriptor(
      kind: NetworkProviderKind.socks5,
      name: 'SOCKS5',
      protocols: {ProviderProtocol.socks5},
      capabilities: ProviderCapabilities(tcp: true, udp: true, ipv4: true, browserProxy: true),
    ),
    NetworkProviderKind.singbox: NetworkProviderDescriptor(
      kind: NetworkProviderKind.singbox,
      name: 'sing-box',
      protocols: {
        ProviderProtocol.shadowsocks,
        ProviderProtocol.vmess,
        ProviderProtocol.vless,
        ProviderProtocol.trojan,
        ProviderProtocol.naive,
        ProviderProtocol.hysteria,
        ProviderProtocol.hysteria2,
        ProviderProtocol.tuic,
        ProviderProtocol.ssh,
        ProviderProtocol.wireguard,
        ProviderProtocol.shadowTls,
        ProviderProtocol.anyTls,
        ProviderProtocol.customOutbound,
      },
      capabilities: ProviderCapabilities(
        tcp: true,
        udp: true,
        ipv4: true,
        ipv6: true,
        dns: true,
        tun: true,
        browserProxy: true,
      ),
    ),
    NetworkProviderKind.ssh: NetworkProviderDescriptor(
      kind: NetworkProviderKind.ssh,
      name: 'SSH',
      protocols: {ProviderProtocol.ssh},
      capabilities: ProviderCapabilities(tcp: true, ipv4: true, browserProxy: true),
    ),
    NetworkProviderKind.wireguard: NetworkProviderDescriptor(
      kind: NetworkProviderKind.wireguard,
      name: 'WireGuard',
      protocols: {ProviderProtocol.wireguard},
      capabilities: ProviderCapabilities(
        tcp: true,
        udp: true,
        ipv4: true,
        ipv6: true,
        dns: true,
        tun: true,
      ),
    ),
    NetworkProviderKind.vpnTun: NetworkProviderDescriptor(
      kind: NetworkProviderKind.vpnTun,
      name: '系统 VPN / TUN',
      protocols: {ProviderProtocol.none},
      capabilities: ProviderCapabilities(
        tcp: true,
        udp: true,
        ipv4: true,
        ipv6: true,
        dns: true,
        tun: true,
      ),
    ),
    NetworkProviderKind.tor: NetworkProviderDescriptor(
      kind: NetworkProviderKind.tor,
      name: 'Tor',
      protocols: {ProviderProtocol.none},
      capabilities: ProviderCapabilities(tcp: true, ipv4: true, browserProxy: true),
    ),
  };

  static NetworkProviderDescriptor get(NetworkProviderKind kind) {
    final descriptor = descriptors[kind];
    if (descriptor == null) {
      throw StateError('未注册的 Network Provider: $kind');
    }
    return descriptor;
  }

  static bool supports(NetworkRoute route) {
    final descriptor = descriptors[route.provider];
    if (descriptor == null) return false;
    return descriptor.protocols.contains(route.protocol);
  }
}
