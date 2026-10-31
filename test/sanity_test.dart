import 'package:test/test.dart';

void main() {
  test('environment sanity check', () {
    const appName = 'suoro';
    expect(appName, equals('suoro'));
  });
}
