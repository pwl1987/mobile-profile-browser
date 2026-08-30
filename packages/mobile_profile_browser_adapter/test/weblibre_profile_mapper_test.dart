import 'package:mobile_profile_browser_adapter/mobile_profile_browser_adapter.dart';
import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:test/test.dart';

void main() {
  MobileProfile profileWithRef(String ref) {
    final now = DateTime.utc(2026, 8, 30, 9);
    return MobileProfile(
      id: '11111111-1111-4111-8111-111111111111',
      name: '映射测试',
      createdAt: now,
      updatedAt: now,
      browserProfileRef: ref,
      deviceProfileRef: 'device-x',
      networkRouteRef: 'route-x',
      status: ProfileStatus.ready,
    );
  }

  test('合法 browser-<uuid> 引用映射出上游身份与目录', () {
    const uuid = '0f1e2d3c-4b5a-6978-8a9b-0c1d2e3f4a5b';
    final handle = WebLibreProfileMapper.handleFor(profileWithRef('browser-$uuid'));

    expect(handle.id, uuid);
    expect(handle.storageNamespace, 'weblibre_profiles/profile-$uuid');
  });

  test('storageNamespace 与上游目录布局规则一致', () {
    final namespace =
        WebLibreProfileMapper.storageNamespaceOf('0f1e2d3c-4b5a-6978-8a9b-0c1d2e3f4a5b');
    expect(namespace, matches(RegExp(
      r'^weblibre_profiles/profile-[0-9a-fA-F-]{36}$',
    )));
  });

  test('拒绝缺失 browser- 前缀的引用', () {
    expect(
      () => WebLibreProfileMapper.browserProfileIdOf(profileWithRef('0f1e2d3c-4b5a-6978-8a9b-0c1d2e3f4a5b')),
      throwsA(isA<WebLibreProfileMappingError>()),
    );
  });

  test('拒绝非 UUID 的引用（上游目录段要求 36 位 UUID）', () {
    expect(
      () => WebLibreProfileMapper.browserProfileIdOf(profileWithRef('browser-not-a-uuid')),
      throwsA(isA<WebLibreProfileMappingError>()),
    );
  });

  test('M2 生成的 browserProfileRef（UUID v4）可以被映射', () {
    final ref = ProfileIdentity.newBrowserProfileRef();
    final id = WebLibreProfileMapper.browserProfileIdOf(profileWithRef(ref));
    expect(WebLibreProfileMapper.isValidBrowserProfileId(id), isTrue);
  });
}
