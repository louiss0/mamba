import 'package:mamba/built_in_flags.dart';
import 'package:mamba/errors.dart';
import 'package:test/test.dart';

/// The spellings Mamba claims for itself, and how it says so when it fails.
///
/// These are the two places the framework names its own behaviour: the tokens
/// it reads whatever a command declares, and the text a user reads when a
/// declaration or an invocation is wrong.
void main() {
  group('MambaBuiltInFlags', () {
    test('reads a control letter out of a clustered short group', () {
      expect(MambaBuiltInFlags.isControl('-xh'), isTrue);
      expect(MambaBuiltInFlags.isControl('-xV'), isTrue);
      expect(MambaBuiltInFlags.isControl('-x'), isFalse);
      expect(MambaBuiltInFlags.isControl('-'), isFalse);
      expect(MambaBuiltInFlags.isControl('--verbose'), isFalse);
    });

    test('separates help from version', () {
      expect(MambaBuiltInFlags.isHelp('-h'), isTrue);
      expect(MambaBuiltInFlags.isHelp('--help'), isTrue);
      expect(MambaBuiltInFlags.isHelp('-V'), isFalse);
      expect(MambaBuiltInFlags.isVersion('-V'), isTrue);
      expect(MambaBuiltInFlags.isVersion('--version'), isTrue);
      expect(MambaBuiltInFlags.isVersion('-h'), isFalse);
    });
  });

  group('Mamba errors', () {
    test('names the kind of registry error it is', () {
      expect(
        MambaRegistryError('bad declaration').toString(),
        startsWith('MambaRegistryError: '),
      );
    });

    test('prints a command failure as its own message', () {
      expect(
        MambaException('run failed', exitCode: 7).toString(),
        'run failed',
      );
    });

    test('refuses an exit code a process cannot carry', () {
      expect(() => MambaException('bad', exitCode: 0), throwsArgumentError);
      expect(() => MambaException('bad', exitCode: 256), throwsArgumentError);
    });
  });
}
