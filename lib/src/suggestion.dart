/// The registered term a mistyped word was closest to.
enum SuggestionKind {
  command,
  alias,
  flag,
  option,
  shortFlag;

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
    SuggestionKind.shortFlag => '-$name',
  };

  @override
  bool operator ==(Object other) =>
      other is Suggestion && other.kind == kind && other.name == name;

  @override
  int get hashCode => Object.hash(kind, name);

  @override
  String toString() => display;
}

/// The nearest candidates to [term], closest first.
///
/// Candidates farther away than a share of the term's length are not mistakes,
/// so they are withheld rather than offered as noise. Ties break toward the
/// fuller word, so a command is offered ahead of an alias that sits the same
/// distance away, and the name sorts last to keep the message stable.
List<Suggestion> nearestMatches(
  String term,
  Iterable<Suggestion> candidates, {
  int limit = 3,
}) {
  final ceiling = _reach(term);
  final ranked = <(int, Suggestion)>[];

  for (final candidate in candidates) {
    final distance = _editDistance(term, candidate.name);
    if (distance <= ceiling) ranked.add((distance, candidate));
  }

  ranked.sort((left, right) {
    final byDistance = left.$1.compareTo(right.$1);
    if (byDistance != 0) return byDistance;
    final byKind = left.$2.kind.rank.compareTo(right.$2.kind.rank);
    return byKind != 0 ? byKind : left.$2.name.compareTo(right.$2.name);
  });

  return ranked.take(limit).map((entry) => entry.$2).toList();
}

/// Renders [suggestions] as the tail of a "did you mean" sentence.
String renderSuggestions(List<Suggestion> suggestions) {
  final rendered = suggestions.map((suggestion) => suggestion.display).toList();
  if (rendered.length == 1) return rendered.single;
  if (rendered.length == 2) return '${rendered.first} or ${rendered.last}';
  return '${rendered.take(rendered.length - 1).join(', ')}, '
      'or ${rendered.last}';
}

/// Builds the trailing advice for a rejection, or nothing when no candidate
/// sits close enough to be worth guessing.
String adviceFor(String term, Iterable<Suggestion> candidates) {
  final matches = nearestMatches(term, candidates);
  return matches.isEmpty ? '' : ' Did you mean ${renderSuggestions(matches)}?';
}

/// How far a candidate may sit from the term and still count as a typo.
///
/// Half the term's own length keeps a long word forgiving and a short one
/// strict. A one-letter word therefore reaches no candidate at all, because
/// every other single letter is one edit away and offering all of them says
/// nothing.
int _reach(String term) => term.length ~/ 2;

/// The number of edits that turn [from] into [to].
///
/// Swapping two adjacent letters counts as one edit, because a transposition
/// is the most common way to mistype a word and plain Levenshtein scores it as
/// two, which ranked it behind an unrelated shorter alias at the same distance.
int _editDistance(String from, String to) {
  if (from == to) return 0;
  if (from.isEmpty) return to.length;
  if (to.isEmpty) return from.length;

  final rows = List.generate(
    from.length + 1,
    (row) => List<int>.filled(to.length + 1, 0),
    growable: false,
  );

  for (var column = 0; column <= to.length; column++) {
    rows[0][column] = column;
  }
  for (var row = 0; row <= from.length; row++) {
    rows[row][0] = row;
  }

  for (var row = 1; row <= from.length; row++) {
    for (var column = 1; column <= to.length; column++) {
      final substitution =
          rows[row - 1][column - 1] + (from[row - 1] == to[column - 1] ? 0 : 1);
      final deletion = rows[row - 1][column] + 1;
      final insertion = rows[row][column - 1] + 1;
      var best = substitution < deletion ? substitution : deletion;
      if (insertion < best) best = insertion;

      final transposed =
          row > 1 &&
          column > 1 &&
          from[row - 1] == to[column - 2] &&
          from[row - 2] == to[column - 1];
      if (transposed) {
        final swap = rows[row - 2][column - 2] + 1;
        if (swap < best) best = swap;
      }

      rows[row][column] = best;
    }
  }

  return rows[from.length][to.length];
}
