import 'package:mobile_profile_domain/mobile_profile_domain.dart';

import 'runtime_handles.dart';

/// WebLibre/Gecko Profile 的业务适配契约。
///
/// 实现层负责把本项目的 MobileProfile 映射到上游浏览器 Profile，
/// 并保证 Profile 数据目录的所有权关系可追踪。
abstract interface class BrowserProfileAdapter {
  Future<BrowserProfileHandle> ensureProfile(MobileProfile profile);

  Future<void> prepareProfile(BrowserProfileHandle handle);

  Future<void> deleteProfile(BrowserProfileHandle handle);
}

/// 浏览器 Runtime 生命周期契约。
abstract interface class BrowserRuntimeAdapter {
  Future<BrowserRuntimeHandle> start({
    required MobileProfile profile,
    required BrowserProfileHandle browserProfile,
  });

  Future<void> stop(BrowserRuntimeHandle runtime);
}
