import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import 'package:suoro/core/network/http_client_node.dart';
import 'package:suoro/core/network/http_server_node.dart';
import 'package:suoro/core/session/session_models.dart';
import 'package:suoro/core/session/transfer_state_machine.dart';
import 'package:suoro/core/storage/storage_service.dart';

void main() {
  test('E2E Loopback: Node A streams 1MB file to Node B and verifies SHA-256 hash', () async {
    final dirA = Directory.systemTemp.createTempSync('node_a_');
    final dirB = Directory.systemTemp.createTempSync('node_b_');

    // Create 1MB binary test file on Node A
    final fileA = File('${dirA.path}/source_data.bin');
    final rawBytes = List<int>.generate(1024 * 1024, (i) => i % 256);
    fileA.writeAsBytesSync(rawBytes);
    final expectedHash = sha256.convert(rawBytes).toString();

    // Node B (Receiver)
    final storageB = StorageService(baseDirectory: dirB);
    final smB = TransferStateMachine();
    final nodeB = HttpServerNode(
      deviceInfo: const PeerDevice(id: 'node-b', name: 'Receiver-PC', os: 'windows', host: '127.0.0.1', port: 0),
      storageService: storageB,
      stateMachine: smB,
      autoAcceptForTesting: true,
    );
    final serverB = await nodeB.start(port: 0);

    // Node A (Sender)
    final clientA = HttpClientNode();
    final peerB = PeerDevice(id: 'node-b', name: 'Receiver-PC', os: 'windows', host: '127.0.0.1', port: serverB.port);
    final item = TransferItem(id: 'item-0', name: 'source_data.bin', size: fileA.lengthSync(), mime: 'application/octet-stream');

    final accepted = await clientA.requestTransfer(
      peer: peerB,
      sessionId: 'e2e-session-uuid',
      sender: const PeerDevice(id: 'node-a', name: 'Sender-PC', os: 'windows', host: '127.0.0.1', port: 0),
      items: [item],
    );
    expect(accepted, isTrue);

    final streamOk = await clientA.streamFile(
      peer: peerB,
      sessionId: 'e2e-session-uuid',
      file: fileA,
    );
    expect(streamOk, isTrue);

    // Verify file written to Node B
    final receivedFile = File('${dirB.path}/source_data.bin');
    expect(receivedFile.existsSync(), isTrue);
    final receivedBytes = receivedFile.readAsBytesSync();
    final actualHash = sha256.convert(receivedBytes).toString();
    expect(actualHash, equals(expectedHash));

    // Cleanup
    await nodeB.stop();
    clientA.close();
    dirA.deleteSync(recursive: true);
    dirB.deleteSync(recursive: true);
  });
}
