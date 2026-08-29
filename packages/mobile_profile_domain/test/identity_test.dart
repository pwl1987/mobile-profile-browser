import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:test/test.dart';

void main() {
  test('UUID v4 格式：小写十六进制、版本位 4、RFC 4122 variant', () {
    final id = ProfileIdentity.newUuidV4();
    expect(
      id,
      matches(RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      )),
    );
  });

  test('批量生成不出现重复 id', () {
    final ids = <String>{};
    for (var i = 0; i < 2000; i++) {
      ids.add(ProfileIdentity.newProfileId());
    }
    expect(ids.length, 2000);
  });

  test('browserProfileRef 带前缀且包含独立 UUID', () {
    final refA = ProfileIdentity.newBrowserProfileRef();
    final refB = ProfileIdentity.newBrowserProfileRef();
    expect(refA, startsWith('browser-'));
    expect(refA, isNot(equals(refB)));
    expect(refA.substring('browser-'.length), isNot(equals(refB.substring('browser-'.length))));
  });
}
