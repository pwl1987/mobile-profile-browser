import 'package:mobile_profile_weblibre/mobile_profile_weblibre.dart';
import 'package:test/test.dart';

void main() {
  const handle = WebLibreRuntimeHandle(
    profileId: 'p1',
    browserProfileId: '0f1e2d3c-4b5a-6978-8a9b-0c1d2e3f4a5b',
    state: WebLibreRuntimeState.created,
  );

  test('合法生命周期：created→starting→running→stopping→stopped', () {
    final running = WebLibreRuntimeController.transition(
      WebLibreRuntimeController.transition(handle, WebLibreRuntimeState.starting),
      WebLibreRuntimeState.running,
    );
    final stopped = WebLibreRuntimeController.transition(
      WebLibreRuntimeController.transition(running, WebLibreRuntimeState.stopping),
      WebLibreRuntimeState.stopped,
    );
    expect(running.state, WebLibreRuntimeState.running);
    expect(stopped.state, WebLibreRuntimeState.stopped);
    expect(stopped.profileId, handle.profileId);
    expect(stopped.browserProfileId, handle.browserProfileId);
  });

  test('stopped/failed 可以重新 starting（重启与重试）', () {
    const stopped = WebLibreRuntimeHandle(
      profileId: 'p1',
      browserProfileId: '0f1e2d3c-4b5a-6978-8a9b-0c1d2e3f4a5b',
      state: WebLibreRuntimeState.stopped,
    );
    const failed = WebLibreRuntimeHandle(
      profileId: 'p1',
      browserProfileId: '0f1e2d3c-4b5a-6978-8a9b-0c1d2e3f4a5b',
      state: WebLibreRuntimeState.failed,
    );
    expect(
      WebLibreRuntimeController.transition(stopped, WebLibreRuntimeState.starting).state,
      WebLibreRuntimeState.starting,
    );
    expect(
      WebLibreRuntimeController.transition(failed, WebLibreRuntimeState.starting).state,
      WebLibreRuntimeState.starting,
    );
  });

  test('非法跳转被拒绝', () {
    expect(
      () => WebLibreRuntimeController.transition(handle, WebLibreRuntimeState.running),
      throwsA(isA<WebLibreRuntimeStateError>()),
    );
    const running = WebLibreRuntimeHandle(
      profileId: 'p1',
      browserProfileId: '0f1e2d3c-4b5a-6978-8a9b-0c1d2e3f4a5b',
      state: WebLibreRuntimeState.running,
    );
    expect(
      () => WebLibreRuntimeController.transition(running, WebLibreRuntimeState.created),
      throwsA(isA<WebLibreRuntimeStateError>()),
    );
  });
}
