import 'package:mamba/mamba.dart' show CliIO;

final class ScriptedCliIO(List<String> answers) implements CliIO {
  final Iterator<String> _answers = answers.iterator;
  final output = StringBuffer();
  var reads = 0;

  @override
  bool get isTTY => false;

  @override
  String readLine() {
    reads++;
    if (!_answers.moveNext()) throw StateError('Scripted input exhausted.');
    return _answers.current;
  }

  @override
  void write(String text) => output.write(text);

  @override
  void writeln([String text = '']) => output.writeln(text);
}
