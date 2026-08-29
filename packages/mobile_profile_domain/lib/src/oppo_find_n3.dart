import 'mobile_profile.dart';

/// OPPO Find N3 的硬件能力基线。
///
/// 这些值来自 OPPO 官方规格，实际 Android window metrics、DPR、语言、时区
/// 和浏览器能力仍以真机运行时观测为准。
final class OppoFindN3Profiles {
  OppoFindN3Profiles._();

  static const china = DeviceProfile(
    id: 'device-oppo-find-n3-cn',
    name: 'OPPO Find N3（中国大陆）',
    deviceFamily: 'OPPO Find N3',
    model: 'OPPO Find N3',
    regionalModel: 'PHN110',
    androidVersion: '13',
    mainDisplay: DisplayProfile(
      surface: DisplaySurface.main,
      resolutionWidth: 2440,
      resolutionHeight: 2268,
      refreshRateHz: 120,
      touchSamplingRateHz: 240,
    ),
    coverDisplay: DisplayProfile(
      surface: DisplaySurface.cover,
      resolutionWidth: 2484,
      resolutionHeight: 1116,
      refreshRateHz: 120,
      touchSamplingRateHz: 240,
    ),
    posture: FoldablePosture.unfolded,
    hardwareConcurrency: 8,
    maxTouchPoints: 5,
    clientHintsState: CapabilityState.observed,
    webglState: CapabilityState.observed,
  );

  /// 国际版同一硬件家族使用不同区域型号，实际系统信息必须运行时确认。
  static const international = DeviceProfile(
    id: 'device-oppo-find-n3-intl',
    name: 'OPPO Find N3（国际版）',
    deviceFamily: 'OPPO Find N3',
    model: 'OPPO Find N3',
    regionalModel: 'CPH2499',
    androidVersion: '13',
    mainDisplay: DeviceProfileFactory.mainDisplay,
    coverDisplay: DeviceProfileFactory.coverDisplay,
    posture: FoldablePosture.unfolded,
    hardwareConcurrency: 8,
    maxTouchPoints: 5,
    clientHintsState: CapabilityState.observed,
    webglState: CapabilityState.observed,
  );
}

final class DeviceProfileFactory {
  DeviceProfileFactory._();

  static const mainDisplay = DisplayProfile(
    surface: DisplaySurface.main,
    resolutionWidth: 2440,
    resolutionHeight: 2268,
    refreshRateHz: 120,
    touchSamplingRateHz: 240,
  );

  static const coverDisplay = DisplayProfile(
    surface: DisplaySurface.cover,
    resolutionWidth: 2484,
    resolutionHeight: 1116,
    refreshRateHz: 120,
    touchSamplingRateHz: 240,
  );
}
