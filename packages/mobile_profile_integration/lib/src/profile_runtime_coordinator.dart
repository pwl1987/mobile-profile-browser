import 'package:mobile_profile_domain/mobile_profile_domain.dart';

import 'browser_profile_adapter.dart';
import 'network_runtime.dart';
import 'runtime_handles.dart';

/// 负责把一个 MobileProfile 的浏览器 Runtime 与网络 Runtime 串成单一启动/停止事务。
///
/// 这里不实现 GeckoView、sing-box 或 Android API，只协调边界并保证失败时的
/// 清理顺序：网络先建立，浏览器再启动；停止时浏览器先退出，再释放网络。
final class ProfileRuntimeCoordinator {
  ProfileRuntimeCoordinator({
    required this.browserProfileAdapter,
    required this.browserRuntimeAdapter,
    required this.networkRuntimeFactory,
  });

  final BrowserProfileAdapter browserProfileAdapter;
  final BrowserRuntimeAdapter browserRuntimeAdapter;
  final NetworkRuntimeFactory networkRuntimeFactory;

  Future<ProfileRuntimeSession> start({
    required MobileProfile profile,
    required RuntimeInstance runtime,
    required NetworkRoute route,
  }) async {
    final browserProfile = await browserProfileAdapter.ensureProfile(profile);
    await browserProfileAdapter.prepareProfile(browserProfile);

    final networkRuntime = networkRuntimeFactory.create(route);
    final networkStatus = await networkRuntime.start(runtime, route);
    if (networkStatus != NetworkRouteStatus.connected) {
      await networkRuntime.stop(runtime);
      throw StateError('网络 Runtime 未进入 connected：${networkStatus.name}');
    }

    try {
      final browserRuntime = await browserRuntimeAdapter.start(
        profile: profile,
        browserProfile: browserProfile,
      );
      return ProfileRuntimeSession(
        browserProfile: browserProfile,
        browserRuntime: browserRuntime,
        runtime: runtime,
        networkRuntime: networkRuntime,
      );
    } catch (_) {
      await networkRuntime.stop(runtime);
      rethrow;
    }
  }

  Future<void> stop(ProfileRuntimeSession session) async {
    Object? firstError;
    try {
      await browserRuntimeAdapter.stop(session.browserRuntime);
    } catch (error) {
      firstError = error;
    }

    try {
      await session.networkRuntime.stop(session.runtime);
    } catch (error) {
      firstError ??= error;
    }

    if (firstError != null) {
      Error.throwWithStackTrace(firstError, StackTrace.current);
    }
  }
}

final class ProfileRuntimeSession {
  const ProfileRuntimeSession({
    required this.browserProfile,
    required this.browserRuntime,
    required this.runtime,
    required this.networkRuntime,
  });

  final BrowserProfileHandle browserProfile;
  final BrowserRuntimeHandle browserRuntime;
  final RuntimeInstance runtime;
  final NetworkRuntimeAdapter networkRuntime;
}
