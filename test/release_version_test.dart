import '../tool/release.dart';

import 'package:test/test.dart';

void main() {
  group('release versions', () {
    for (final version in ['0.0.0', '1.2.3', '1.2.3-rc.1']) {
      test('accepts $version', () {
        expect(isReleaseVersion(version), isTrue);
      });
    }

    for (final version in [
      'v1.2.3',
      '01.2.3',
      '1.2',
      '1.2.3-01',
      '1.2.3-alpha..1',
      '1.2.3+build.42',
    ]) {
      test('rejects $version', () {
        expect(isReleaseVersion(version), isFalse);
      });
    }
  });

  group('release tags', () {
    test('accepts a valid v-prefixed prerelease tag', () {
      expect(isReleaseTag('v1.2.3-rc.1'), isTrue);
    });

    for (final tag in ['1.2.3', 'v1.2.3+build.42', 'v01.2.3']) {
      test('rejects $tag', () {
        expect(isReleaseTag(tag), isFalse);
      });
    }
  });
}
