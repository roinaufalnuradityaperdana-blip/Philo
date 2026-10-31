import 'dart:io';
import 'package:test/test.dart';
import 'package:suoro/core/network/http_client_node.dart';
import 'package:suoro/core/network/http_server_node.dart';
import 'package:suoro/core/session/session_models.dart';
import 'package:suoro/core/session/transfer_state_machine.dart';
import 'package:suoro/core/storage/storage_service.dart';

void main() {
  group('HttpClientNode Transfer Tests', () {
    late Directory tempDir;
    late HttpServerNode serverNode;
    late HttpClientNode clientNode;
    late int serverPort;
    late File sampleFile;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('client_test_');
      sampleFile = File('${tempDir.path}/upload.txt');
      sampleFile.writeAsStringSync('Hello Suoro P2P File Transfer!');

      final storage = StorageService(baseDirectory: tempDir);
      final sm = TransferStateMachine();
      serverNode = HttpServerNode(
        deviceInfo: const PeerDevice(id: 'srv-1', name: 'Server', os: 'windows', host: '127.0.0.1', port: 0),
        storageService: storage,
        stateMachine: sm,
        autoAcceptForTesting: true,
      );
      final s = await serverNode.start(port: 0);
      serverPort = s.port;

      clientNode = HttpClientNode();
    });

    tearDown(() async {
      await serverNode.stop();
      tempDir.deleteSync(recursive: true);
    });

    test('sendText sends payload successfully', () async {
      final peer = PeerDevice(id: 'srv-1', name: 'Server', os: 'windows', host: '127.0.0.1', port: serverPort);
      final ok = await clientNode.sendText(peer: peer, text: 'Short clip message');
      expect(ok, isTrue);
    });

    test('sendFile transfers binary file to server', () async {
      final peer = PeerDevice(id: 'srv-1', name: 'Server', os: 'windows', host: '127.0.0.1', port: serverPort);
      final item = TransferItem(id: 'item-1', name: 'upload.txt', size: sampleFile.lengthSync(), mime: 'text/plain');

      final accepted = await clientNode.requestTransfer(
        peer: peer,
        sessionId: 'test-session-1',
        sender: const PeerDevice(id: 'cli-1', name: 'Client', os: 'android', host: '127.0.0.1', port: 0),
        items: [item],
      );
      expect(accepted, isTrue);

      final ok = await clientNode.streamFile(
        peer: peer,
        sessionId: 'test-session-1',
        file: sampleFile,
      );
      expect(ok, isTrue);
    });
  });
}
