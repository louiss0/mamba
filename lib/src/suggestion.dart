/// The registered term a mistyped word was closest to.
enum SuggestionKind {
  command,
  alias,
  flag,
  option;

  /// How strongly this kind is preferred when two candidates tie.
  int get rank => index;
}

/// A registered [SuggestionKind] term offered as a possible intent.
final class Suggestion {
  const new(this.kind, this.name);

  final SuggestionKind kind;
  final String name;

  /// How the term is written inside an error message.
  ///
  /// A command is named as a kind because a reader has to know whether the word
  /// they half-remembered was a command, an alias, or neither. An option is
  /// written as the token it is typed as, because the message carrying the
  /// suggestion already names flags and options together.
  String get display => switch (kind) {
    SuggestionKind.command => "the command '$name'",
    SuggestionKind.alias => "the alias '$name'",
    SuggestionKind.flag || SuggestionKind.option => '--$name',
  };

  @override
  bool operator ==(Object other) =>
      other is Suggestion && other.kind == kind && other.name == name;

  @override
  int get hashCode => Object.hash(kind, name);

  @override
  String toString() => display;
}

/// How much of a name a reader must type before a suggestion is worth making.
///
/// One letter is not enough: a single letter is a prefix of most of any
/// registry, and offering all of them says nothing about which was meant.
const _minimumPrefix = 2;

/// The candidates whose name begins with [term], most specific first.
///
/// Matching on the prefix a reader actually typed is predictable: the same
/// input always means the same completion, and an abbreviation that is not a
/// typo still resolves. A shorter name is the more specific completion of the
/// same prefix, so it leads, and a command is offered ahead of an alias of the
/// same length.
List<Suggestion> prefixMatches(
  String term,
  Iterable<Suggestion> candidates, {
  int limit = 3,
}) {
  if (term.length < _minimumPrefix) return const [];

  final matched = candidates
      .where((candidate) => candidate.name.startsWith(term))
      .toList();

  matched.sort((left, right) {
    final byLength = left.name.length.compareTo(right.name.length);
    if (byLength != 0) return byLength;
    final byKind = left.kind.rank.compareTo(right.kind.rank);
    return byKind != 0 ? byKind : left.name.compareTo(right.name);
  });

  return matched.take(limit).toList();
}

/// Renders [suggestions] as the tail of a "did you mean" sentence.
String renderSuggestions(List<Suggestion> suggestions) {
  final rendered = suggestions.map((suggestion) => suggestion.display).toList();
  if (rendered.length == 1) return rendered.single;
  if (rendered.length == 2) return '${rendered.first} or ${rendered.last}';
  return '${rendered.take(rendered.length - 1).join(', ')}, '
      'or ${rendered.last}';
}

/// Builds the trailing advice for a rejection, or nothing when no registered
/// name begins with what was typed.
String adviceFor(String term, Iterable<Suggestion> candidates) {
  final matches = prefixMatches(term, candidates);
  return matches.isEmpty ? '' : ' Did you mean ${renderSuggestions(matches)}?';
}
