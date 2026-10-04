import 'dart:convert';

/// Data read from the invocation's standard input.
///
/// [bytes] is the raw stream. The getters decode it: [text] is UTF-8, which is
/// what a command-line tool receives, and [json] is that text parsed as JSON.
final class ProcessedStandardInput {
  const new(this.bytes);
  final List<int> bytes;

  /// [bytes] decoded as UTF-8.
  String get text => utf8Text;

  String get utf8Text => utf8.decode(bytes);
  dynamic get json => jsonDecode(utf8Text);
}
