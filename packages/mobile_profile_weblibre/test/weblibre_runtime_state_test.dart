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

  test('unknown 恢复语义（ADR-004）：声称存活可降级，收敛后可判活/判死', () {
    const running = WebLibreRuntimeHandle(
      profileId: 'p1',
      browserProfileId: '0f1e2d3c-4b5a-6978-8a9b-0c1d2e3f4a5b',
      state: WebLibreRuntimeState.running,
    );
    // running → unknown（进程死亡后知识失效）。
    final unknown = WebLibreRuntimeController.transition(
        running, WebLibreRuntimeState.unknown);
    expect(unknown.state, WebLibreRuntimeState.unknown);
    // unknown → stopped（新进程内旧 runtime 必死）。
    expect(
      WebLibreRuntimeController.transition(
              unknown, WebLibreRuntimeState.stopped)
          .state,
      WebLibreRuntimeState.stopped,
    );

    // created/stopped/failed 不能直接进 unknown。
    expect(
      WebLibreRuntimeController.canTransition(
          WebLibreRuntimeState.created, WebLibreRuntimeState.unknown),
      isFalse,
    );
    expect(
      WebLibreRuntimeController.canTransition(
          WebLibreRuntimeState.stopped, WebLibreRuntimeState.unknown),
      isFalse,
    );
  });
}
