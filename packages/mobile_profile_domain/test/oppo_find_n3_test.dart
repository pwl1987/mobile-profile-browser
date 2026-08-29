import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:test/test.dart';

void main() {
  test('OPPO Find N3 中国大陆版基线包含内外屏', () {
    final profile = OppoFindN3Profiles.china;

    expect(profile.regionalModel, 'PHN110');
    expect(profile.mainDisplay?.resolutionWidth, 2440);
    expect(profile.mainDisplay?.resolutionHeight, 2268);
    expect(profile.coverDisplay?.resolutionWidth, 2484);
    expect(profile.coverDisplay?.resolutionHeight, 1116);
    expect(profile.hardwareConcurrency, 8);
    expect(profile.maxTouchPoints, 5);
  });

  test('Find N3 是折叠设备，不应被建模为单一固定屏幕', () {
    final profile = OppoFindN3Profiles.china;

    expect(profile.mainDisplay, isNotNull);
    expect(profile.coverDisplay, isNotNull);
    expect(profile.mainDisplay!.surface, DisplaySurface.main);
    expect(profile.coverDisplay!.surface, DisplaySurface.cover);
  });
}
