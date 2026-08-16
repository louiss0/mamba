import 'package:arg_parser/help_formatter.dart';
import 'package:arg_parser/registry.dart';
import 'package:chalkdart/chalkstrings.dart';
import 'package:test/test.dart';

void main() {
  group('Formatted strings', () {
    test('requires ANSI styling and valid delimiters', () {
      expect(() => RequiredString('value'), throwsFormatException);
      expect(() => RequiredString('< value >'.red), throwsFormatException);
      expect(RequiredString('value'.red).string, contains('value'));
      expect(VariadicString('value'.red).string, startsWith('...'));
    });
  });

  group('HelpFormatter', () {
    test('formats list-defined command inputs and nested accessors', () {
      final registry = CommandRegistry.create(
        'curl',
        'Transfer data.',
        longDescription: 'A compact HTTP client.',
        flags: [BooleanFlag(name: 'verbose', short: 'v')],
        options: [
          StringOption(name: 'output', short: 'o', regex: RegExp(r'\S+')),
          RepeatableStringOption(name: 'header', short: 'H'),
        ],
        accessors: [
          AccessorListOption(
            name: 'tls',
            options: [AccessorStringOption(name: 'cert')],
          ),
        ],
        mandatoryPositionals: [Positional('url')],
        discretionaryPositionals: [Positional('output')],
        variadic: Variadic('arguments'),
      );

      final help = HelpFormatter().formatHelp(registry);

      expect(help, contains('curl'));
      expect(help, contains('url'));
      expect(help, contains('arguments'));
      expect(help, contains('verbose'));
      expect(help, contains('output'));
      expect(help, contains('header'));
      expect(help, contains('tls.cert'));
    });
  });
}
