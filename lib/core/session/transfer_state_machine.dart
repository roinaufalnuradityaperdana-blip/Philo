import 'package:uuid/uuid.dart';
import 'session_models.dart';

class TransferStateMachine {
  TransferSessionState _state = TransferSessionState.idle;
  TransferSession? _currentSession;
  String? _failureReason;

  TransferSessionState get state => _state;
  TransferSession? get currentSession => _currentSession;
  String? get failureReason => _failureReason;

  void startOutgoingRequest({
    required PeerDevice peer,
    required List<TransferItem> items,
    String? text,
  }) {
    if (_state != TransferSessionState.idle) {
      throw StateError('Cannot start request while state is $_state');
    }
    final sessionId = const Uuid().v4();
    _currentSession = TransferSession(
      sessionId: sessionId,
      peer: peer,
      items: items,
      text: text,
      isOutgoing: true,
    );
    _state = TransferSessionState.requestPending;
    _failureReason = null;
  }

  void receiveIncomingRequest({
    required String sessionId,
    required PeerDevice peer,
    required List<TransferItem> items,
    String? text,
  }) {
    if (_state != TransferSessionState.idle) {
      throw StateError('Cannot receive request while busy in $_state');
    }
    _currentSession = TransferSession(
      sessionId: sessionId,
      peer: peer,
      items: items,
      text: text,
      isOutgoing: false,
    );
    _state = TransferSessionState.requestPending;
    _failureReason = null;
  }

  void markApproved() {
    if (_state != TransferSessionState.requestPending) {
      throw StateError('Cannot approve session in state $_state');
    }
    _state = TransferSessionState.transferring;
  }

  void updateProgress({required int bytes}) {
    if (_state != TransferSessionState.transferring) return;
    _currentSession?.bytesTransferred = bytes;
  }

  void markCompleted() {
    if (_state != TransferSessionState.transferring) {
      throw StateError('Cannot complete transfer while in $_state');
    }
    _state = TransferSessionState.completed;
  }

  void markRejected() {
    _state = TransferSessionState.rejected;
  }

  void markFailed(String reason) {
    _failureReason = reason;
    _state = TransferSessionState.failed;
  }

  void cancel() {
    _state = TransferSessionState.cancelled;
  }

  void reset() {
    _state = TransferSessionState.idle;
    _currentSession = null;
    _failureReason = null;
  }
}
