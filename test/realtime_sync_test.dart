import 'package:flutter_test/flutter_test.dart';
import 'package:steelcontrol_mobile/services/session_event_service.dart';

void main() {
  test('realtime sem token inicia e encerra com segurança', () async {
    var revokedCalled = false;
    var profileCalled = false;

    final service = SessionEventService(
      token: '',
      onRevoked: (_) async {
        revokedCalled = true;
      },
      onProfile: (_) async {
        profileCalled = true;
      },
    );

    await service.start();
    await service.stop();
    await service.stop();

    expect(revokedCalled, isFalse);
    expect(profileCalled, isFalse);
  });
}
