import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

void main() {
  test('help distinguishes pair and selected groups', () {
    final host = PairStringOption('host');
    final port = PairStringOption('port');
    final pair = PairedOptions([
      host,
      port,
    ], (values) => (values.valueOf(host), values.valueOf(port)));
    final selected = SelectedOptions<String>([
      SelectableOption(PairStringOption('json'), (value) => value),
      SelectableOption(PairStringOption('text'), (value) => value),
    ]);
    final help = MambaHelpFormatter().format(
      CommandRegistry.create(
        'tool',
        'Tool.',
        pairedOptions: [pair],
        selectedOptions: [selected],
      ),
    );
    expect(help, contains('--host & --port'));
    expect(help, contains('--json | --text'));
  });
}
