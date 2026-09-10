import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

void main() {
  test('input declarations retain identity', () {
    final one = StringOption('one');
    final two = StringOption('two');
    expect(identical(one, two), isFalse);
  });
}
