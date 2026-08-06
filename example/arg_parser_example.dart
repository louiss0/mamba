import 'dart:io';

import 'package:arg_parser/arg_parser.dart';

void main(List<String> tokens) {
  final parser = ArgParser(
    options: {'verbose': const BooleanOption(alias: 'v')},
    commands: [
      ArgCommand(
        'create',
        aliases: const {'new'},
        accessors: {
          'user': {
            'name': const StringOption(required: true),
            'admin': const BooleanOption(),
          },
        },
      ),
    ],
  );

  switch (parser.parse(tokens)) {
    case ArgParseSuccess(:final arguments):
      print('command: ${arguments.commandPath.join(' ')}');
      print('values: ${arguments.values}');
    case ArgParseFailure(:final error):
      stderr.writeln('Error: ${error.message}');
      exitCode = 64;
  }
}
