import 'package:test/test.dart';
import 'package:suoro/core/session/session_models.dart';
import 'package:suoro/core/session/transfer_state_machine.dart';

void main() {
  group('TransferStateMachine Tests', () {
    test('initial state is idle', () {
      final sm = TransferStateMachine();
      expect(sm.state, equals(TransferSessionState.idle));
    });

    test('valid transition: idle -> requestPending -> transferring -> completed', () {
      final sm = TransferStateMachine();
      final peer = PeerDevice(id: 'peer-1', name: 'Android-Phone', os: 'android', host: '192.168.1.10', port: 53317);
      final item = TransferItem(id: 'item-1', name: 'photo.jpg', size: 2048, mime: 'image/jpeg');

      sm.startOutgoingRequest(peer: peer, items: [item]);
      expect(sm.state, equals(TransferSessionState.requestPending));
      expect(sm.currentSession?.peer.id, equals('peer-1'));

      sm.markApproved();
      expect(sm.state, equals(TransferSessionState.transferring));

      sm.updateProgress(bytes: 2048);
      expect(sm.currentSession?.bytesTransferred, equals(2048));

      sm.markCompleted();
      expect(sm.state, equals(TransferSessionState.completed));
    });

    test('illegal transition throws StateError', () {
      final sm = TransferStateMachine();
      expect(() => sm.markCompleted(), throwsA(isA<StateError>()));
    });
  });
}
