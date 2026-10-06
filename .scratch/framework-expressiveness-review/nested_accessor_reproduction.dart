import 'dart:io';

import 'package:mamba/mamba.dart';

void main() {
  final nested = AccessorListOption('auth', [AccessorStringOption('token')]);
  final root = AccessorListOption('server', [nested]);
  final registry = CommandRegistry.create(
    'app',
    'Accessor probe.',
    accessors: [root],
  );
  final inputs = Parser(registry).parse([]).$2;
  stdout.writeln('Root handle: ${inputs.valueOf(root)}');
  // Intentionally throws on the current implementation. A valid normal parse
  // must make this non-null container handle readable, even when it is empty.
  stdout.writeln('Nested handle: ${inputs.valueOf(nested)}');
}
