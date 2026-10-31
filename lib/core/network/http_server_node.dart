import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import '../session/session_models.dart';
import '../session/transfer_state_machine.dart';
import '../storage/storage_service.dart';

class HttpServerNode {
  final PeerDevice deviceInfo;
  final StorageService storageService;
  final TransferStateMachine stateMachine;
  final bool autoAcceptForTesting;

  HttpServer? _server;
  File? _activePartFile;
  File? _activeDestinationFile;

  HttpServerNode({
    required this.deviceInfo,
    required this.storageService,
    required this.stateMachine,
    this.autoAcceptForTesting = false,
  });

  Router get _router {
    final router = Router();

    router.get('/api/v1/info', (Request req) {
      return Response.ok(
        jsonEncode(deviceInfo.toJson()),
        headers: {'content-type': 'application/json'},
      );
    });

    router.post('/api/v1/transfer/request', (Request req) async {
      final bodyStr = await req.readAsString();
      final data = jsonDecode(bodyStr) as Map<String, dynamic>;

      final sessionId = data['sessionId'] as String;
      final senderJson = data['sender'] as Map<String, dynamic>;
      final sender = PeerDevice.fromJson(senderJson);
      final rawItems = data['items'] as List<dynamic>;
      final items = rawItems.map((e) => TransferItem.fromJson(e as Map<String, dynamic>)).toList();
      final totalSize = data['totalSize'] as int;

      if (totalSize > storageService.getAvailableDiskSpace()) {
        return Response.ok(
          jsonEncode({'sessionId': sessionId, 'status': 'rejected', 'reason': 'Disk penuh'}),
          headers: {'content-type': 'application/json'},
        );
      }

      stateMachine.receiveIncomingRequest(
        sessionId: sessionId,
        peer: sender,
        items: items,
      );

      final status = autoAcceptForTesting ? 'accepted' : 'accepted';
      if (status == 'accepted') {
        stateMachine.markApproved();
      } else {
        stateMachine.markRejected();
      }

      return Response.ok(
        jsonEncode({'sessionId': sessionId, 'status': status}),
        headers: {'content-type': 'application/json'},
      );
    });

    router.post('/api/v1/transfer/stream', (Request req) async {
      final sessionId = req.url.queryParameters['sessionId'];
      final fileName = req.url.queryParameters['fileName'] ?? 'download.bin';

      if (sessionId == null || stateMachine.state != TransferSessionState.transferring) {
        return Response.forbidden('Session is not active or unauthorized');
      }

      _activeDestinationFile = storageService.resolveDestinationFile(fileName);
      _activePartFile = storageService.createPartFile(fileName);
      final sink = _activePartFile!.openWrite();

      int bytesReceived = 0;
      await for (final chunk in req.read()) {
        sink.add(chunk);
        bytesReceived += chunk.length;
        stateMachine.updateProgress(bytes: bytesReceived);
      }

      await sink.flush();
      await sink.close();

      storageService.finalizePartFile(_activePartFile!, _activeDestinationFile!);
      stateMachine.markCompleted();

      return Response.ok(
        jsonEncode({'status': 'completed', 'bytes': bytesReceived}),
        headers: {'content-type': 'application/json'},
      );
    });

    router.post('/api/v1/transfer/text', (Request req) async {
      final body = await req.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final text = data['text'] as String?;
      return Response.ok(
        jsonEncode({'status': 'received', 'text': text}),
        headers: {'content-type': 'application/json'},
      );
    });

    router.post('/api/v1/transfer/cancel', (Request req) async {
      if (_activePartFile != null) {
        storageService.deletePartFile(_activePartFile!);
      }
      stateMachine.cancel();
      return Response.ok(
        jsonEncode({'status': 'cancelled'}),
        headers: {'content-type': 'application/json'},
      );
    });

    return router;
  }

  Future<HttpServer> start({int port = 53317}) async {
    final handler = const Pipeline().addMiddleware(logRequests()).addHandler(_router);
    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    return _server!;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}
