import 'dart:convert';
import 'dart:io';

import 'package:arg_parser/yargs_command_task_list.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late File dataFile;
  late List<String> output;
  late List<String> errors;
  late YargsCommandTaskListCli cli;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'yargs-command-task-list-test-',
    );
    dataFile = File('${directory.path}${Platform.pathSeparator}.tasks.json');
    output = [];
    errors = [];
    cli = YargsCommandTaskListCli(
      dataFile: dataFile,
      writeOutput: output.add,
      writeError: errors.add,
    );
  });

  tearDown(() => directory.delete(recursive: true));

  test('adds a task through the Yargs command runtime', () async {
    final exitCode = await cli.run([
      'add',
      '  Plan release  ',
      '--description',
      '  Write the release notes.  ',
    ]);

    expect(exitCode, 0);
    expect(output, ['Added task 1: Plan release']);
    expect(errors, isEmpty);
    final document = jsonDecode(await dataFile.readAsString()) as Map;
    expect(document['tasks'], [
      {
        'id': 1,
        'title': 'Plan release',
        'description': 'Write the release notes.',
        'complete': false,
      },
    ]);
  });

  test(
    'uses runtime validation for commands, options, and option choices',
    () async {
      final unknownCommand = await cli.run(['archive']);
      final foreignOption = await cli.run([
        'add',
        'Plan release',
        '--status=all',
      ]);
      final invalidStatus = await cli.run(['list', '--status=archived']);

      expect(unknownCommand, 64);
      expect(foreignOption, 64);
      expect(invalidStatus, 64);
      expect(errors, [
        contains('Unknown command'),
        contains('--status'),
        contains('Expected one of'),
      ]);
    },
  );

  test('deletes a task by ID or all completed tasks', () async {
    await cli.run(['add', 'Keep me']);
    await cli.run(['add', 'Remove me']);
    await cli.run(['update', '2', '--complete=true']);
    output.clear();

    final completedExitCode = await cli.run(['delete', '--completed']);
    final idExitCode = await cli.run(['delete', '1']);

    expect(completedExitCode, 0);
    expect(idExitCode, 0);
    expect(output, ['Deleted 1 completed task.', 'Deleted task 1.']);
  });

  test(
    'requires exactly one update option and supports all update values',
    () async {
      await cli.run(['add', 'Original title']);
      output.clear();

      final invalidExitCode = await cli.run([
        'update',
        '1',
        '--title=New title',
        '--description=New description',
      ]);
      final titleExitCode = await cli.run(['update', '1', '--title=New title']);
      final descriptionExitCode = await cli.run([
        'update',
        '1',
        '--description=Details',
      ]);
      final completionExitCode = await cli.run([
        'update',
        '1',
        '--complete=true',
      ]);

      expect(invalidExitCode, 64);
      expect(titleExitCode, 0);
      expect(descriptionExitCode, 0);
      expect(completionExitCode, 0);
      expect(errors.single, contains('exactly one'));
      expect(output, [
        'Updated task 1 title.',
        'Updated task 1 description.',
        'Updated task 1 completion state.',
      ]);
    },
  );

  test('lists tasks using the default and selected status', () async {
    await cli.run(['add', 'Open task']);
    await cli.run(['add', 'Finished task']);
    await cli.run(['update', '2', '--complete=true']);
    output.clear();

    final completeExitCode = await cli.run(['list', '--status=complete']);

    expect(completeExitCode, 0);
    expect(output, ['2 [complete] Finished task']);
  });
}
