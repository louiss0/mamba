import 'package:mamba/src/suggestion.dart';
import 'package:test/test.dart';

/// What a "did you mean" sentence says when a reader half-remembered a name.
///
/// The ranking is the whole point of the feature: a command leads an alias of
/// the same length, and a shorter name leads a longer one, so the first thing
/// read is the likeliest thing meant.
void main() {
  const config = Suggestion(SuggestionKind.command, 'config');
  const alias = Suggestion(SuggestionKind.alias, 'configure');
  const flag = Suggestion(SuggestionKind.flag, 'verbose');
  const option = Suggestion(SuggestionKind.option, 'output');

  group('display', () {
    test('names a command and an alias as themselves', () {
      expect(config.display, "the command 'config'");
      expect(alias.display, "the alias 'configure'");
    });

    test('writes a flag and an option the way they are typed', () {
      expect(flag.display, '--verbose');
      expect(option.display, '--output');
      expect(option.toString(), '--output', reason: 'rendered as its display');
    });
  });

  group('ranking', () {
    test('leads the shorter name, then the command over the alias', () {
      final ranked = prefixMatches('con', [
        const Suggestion(SuggestionKind.alias, 'config-alias'),
        config,
        alias,
      ]);

      expect(ranked, [
        config,
        alias,
        const Suggestion(SuggestionKind.alias, 'config-alias'),
      ]);
    });

    test('says nothing for a term too short to mean anything', () {
      expect(prefixMatches('c', [config]), isEmpty);
    });

    test('honours the limit', () {
      expect(
        prefixMatches('con', [
          config,
          alias,
          const Suggestion(SuggestionKind.command, 'con2'),
          const Suggestion(SuggestionKind.command, 'con3'),
        ], limit: 2),
        hasLength(2),
      );
    });
  });

  group('equality', () {
    test('compares by kind and name, not by identity', () {
      expect(config, const Suggestion(SuggestionKind.command, 'config'));
      expect(
        config.hashCode,
        const Suggestion(SuggestionKind.command, 'config').hashCode,
      );
      expect(config, isNot(alias));
      expect(
        config,
        isNot(const Suggestion(SuggestionKind.command, 'configure')),
      );
    });
  });

  group('rendering a sentence', () {
    test('reads as one name, two names, or a list', () {
      expect(renderSuggestions([config]), "the command 'config'");
      expect(
        renderSuggestions([config, alias]),
        "the command 'config' or the alias 'configure'",
      );
      expect(
        renderSuggestions([config, alias, flag]),
        "the command 'config', the alias 'configure', or --verbose",
      );
    });
  });
}
