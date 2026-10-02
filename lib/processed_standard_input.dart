import 'dart:convert';

/// Data read from the invocation's standard input.
final class ProcessedStandardInput {
  const new(this.bytes);
  final List<int> bytes;
  String get text => String.fromCharCodes(bytes);
  String get utf8Text => utf8.decode(bytes);
  dynamic get json => jsonDecode(utf8Text);
}
