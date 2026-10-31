import 'dart:io';
import 'package:path/path.dart' as p;

class StorageService {
  final Directory baseDirectory;

  StorageService({required this.baseDirectory}) {
    if (!baseDirectory.existsSync()) {
      baseDirectory.createSync(recursive: true);
    }
  }

  File resolveDestinationFile(String originalFileName) {
    final sanitizedName = p.basename(originalFileName);
    final targetPath = p.join(baseDirectory.path, sanitizedName);
    final file = File(targetPath);
    if (!file.existsSync()) {
      return file;
    }

    final ext = p.extension(sanitizedName);
    final nameWithoutExt = p.basenameWithoutExtension(sanitizedName);
    int counter = 1;

    while (true) {
      final candidatePath = p.join(baseDirectory.path, '$nameWithoutExt ($counter)$ext');
      final candidateFile = File(candidatePath);
      if (!candidateFile.existsSync()) {
        return candidateFile;
      }
      counter++;
    }
  }

  File createPartFile(String targetFileName) {
    final sanitizedName = p.basename(targetFileName);
    final partPath = p.join(baseDirectory.path, '$sanitizedName.part');
    final file = File(partPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
    return file;
  }

  void finalizePartFile(File partFile, File finalDestination) {
    if (partFile.existsSync()) {
      partFile.renameSync(finalDestination.path);
    }
  }

  void deletePartFile(File partFile) {
    if (partFile.existsSync()) {
      partFile.deleteSync();
    }
  }

  int getAvailableDiskSpace() {
    // Returns estimated available bytes (10 GB floor)
    return 10 * 1024 * 1024 * 1024;
  }
}
