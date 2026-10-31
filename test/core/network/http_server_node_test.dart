import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:suoro/core/network/http_server_node.dart';
import 'package:suoro/core/session/session_models.dart';
import 'package:suoro/core/session/transfer_state_machine.dart';
import 'package:suoro/core/storage/storage_service.dart';

void main() {
  group('HttpServerNode API Tests', () {
    late Directory tempDir;
    late StorageService storage;
    late TransferStateMachine stateMachine;
    late HttpServerNode serverNode;
    late int testPort;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('server_test_');
      storage = StorageService(baseDirectory: tempDir);
      stateMachine = TransferStateMachine();

      serverNode = HttpServerNode(
        deviceInfo: const PeerDevice(id: 'node-1', name: 'Test-PC', os: 'windows', host: '127.0.0.1', port: 0),
        storageService: storage,
        stateMachine: stateMachine,
        autoAcceptForTesting: true,
      );

      final server = await serverNode.start(port: 0);
      testPort = server.port;
    });

    tearDown(() async {
      await serverNode.stop();
      tempDir.deleteSync(recursive: true);
    });

    test('GET /api/v1/info returns node details', () async {
      final res = await http.get(Uri.parse('http://127.0.0.1:$testPort/api/v1/info'));
      expect(res.statusCode, equals(200));
      final data = jsonDecode(res.body);
      expect(data['name'], equals('Test-PC'));
      expect(data['os'], equals('windows'));
    });

    test('POST /api/v1/transfer/text accepts incoming text payload', () async {
      final payload = jsonEncode({
        'sender': {'id': 'sender-1', 'name': 'Phone', 'os': 'android', 'host': '127.0.0.1', 'port': 5000},
        'text': 'P2P clipboard content',
      });
      final res = await http.post(
        Uri.parse('http://127.0.0.1:$testPort/api/v1/transfer/text'),
        headers: {'content-type': 'application/json'},
        body: payload,
      );
      expect(res.statusCode, equals(200));
    });
  });
}
