import 'dart:io';
import 'package:test/test.dart';
import 'package:suoro/core/storage/storage_service.dart';

void main() {
  group('StorageService Tests', () {
    late Directory tempDir;
    late StorageService service;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('suoro_test_');
      service = StorageService(baseDirectory: tempDir);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('resolveDestinationFile returns original name when no collision', () {
      final file = service.resolveDestinationFile('document.pdf');
      expect(file.path.endsWith('document.pdf'), isTrue);
    });

    test('resolveDestinationFile appends (1) when collision exists', () {
      File('${tempDir.path}/document.pdf').writeAsStringSync('existing');
      final file = service.resolveDestinationFile('document.pdf');
      expect(file.path.endsWith('document (1).pdf'), isTrue);
    });

    test('createPartFile appends .part extension', () {
      final part = service.createPartFile('video.mp4');
      expect(part.path.endsWith('video.mp4.part'), isTrue);
    });
  });
}
