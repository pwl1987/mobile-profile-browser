import 'package:mobile_profile_weblibre/mobile_profile_weblibre.dart';
import 'package:test/test.dart';

const id = '0f1e2d3c-4b5a-6978-8a9b-0c1d2e3f4a5b';

void main() {
  test('目录布局与上游一致', () {
    expect(
      WebLibreProfilePaths.profilesRoot('/data/user/0/app/files'),
      '/data/user/0/app/files/weblibre_profiles',
    );
    expect(
      WebLibreProfilePaths.profileDir('/data/user/0/app/files', id),
      '/data/user/0/app/files/weblibre_profiles/profile-$id',
    );
    expect(
      WebLibreProfilePaths.metadataFile('/data/user/0/app/files', id),
      '/data/user/0/app/files/weblibre_profiles/profile-$id/metadata.json',
    );
    expect(
      WebLibreProfilePaths.mozillaStorageDir('/data/user/0/app/files', id),
      '/data/user/0/app/files/weblibre_profiles/profile-$id/files/mozilla',
    );
  });

  test('非法 UUID 拒绝拼路径', () {
    expect(
      () => WebLibreProfilePaths.profileDir('/files', 'not-a-uuid'),
      throwsA(anything),
    );
    expect(
      () => WebLibreProfilePaths.mozillaStorageDir('/files', 'x'),
      throwsA(anything),
    );
  });
}
