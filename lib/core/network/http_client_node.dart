import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../session/session_models.dart';

class HttpClientNode {
  final http.Client _client;

  HttpClientNode({http.Client? client}) : _client = client ?? http.Client();

  Future<bool> requestTransfer({
    required PeerDevice peer,
    required String sessionId,
    required PeerDevice sender,
    required List<TransferItem> items,
  }) async {
    final uri = Uri.parse('http://${peer.host}:${peer.port}/api/v1/transfer/request');
    final totalSize = items.fold(0, (sum, i) => sum + i.size);
    final payload = jsonEncode({
      'sessionId': sessionId,
      'sender': sender.toJson(),
      'type': 'file',
      'totalSize': totalSize,
      'items': items.map((e) => e.toJson()).toList(),
    });

    final res = await _client.post(
      uri,
      headers: {'content-type': 'application/json'},
      body: payload,
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['status'] == 'accepted';
    }
    return false;
  }

  Future<bool> streamFile({
    required PeerDevice peer,
    required String sessionId,
    required File file,
    void Function(int bytesSent, int totalBytes)? onProgress,
  }) async {
    final uri = Uri.parse('http://${peer.host}:${peer.port}/api/v1/transfer/stream?sessionId=$sessionId&fileName=${Uri.encodeComponent(file.uri.pathSegments.last)}');
    final request = http.StreamedRequest('POST', uri);
    final totalBytes = file.lengthSync();
    request.contentLength = totalBytes;

    int sent = 0;
    final fileStream = file.openRead();
    fileStream.listen(
      (chunk) {
        request.sink.add(chunk);
        sent += chunk.length;
        onProgress?.call(sent, totalBytes);
      },
      onDone: () => request.sink.close(),
      onError: (err) => request.sink.addError(err),
      cancelOnError: true,
    );

    final response = await _client.send(request);
    return response.statusCode == 200;
  }

  Future<bool> sendText({
    required PeerDevice peer,
    required String text,
  }) async {
    final uri = Uri.parse('http://${peer.host}:${peer.port}/api/v1/transfer/text');
    final res = await _client.post(
      uri,
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'text': text}),
    );
    return res.statusCode == 200;
  }

  void close() {
    _client.close();
  }
}
