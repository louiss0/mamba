import 'dart:convert';
import 'dart:io';

import 'package:arg_parser/yargs_task_list.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late File dataFile;
  late List<String> output;
  late List<String> errors;
  late YargsTaskListCli cli;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('yargs-task-list-test-');
    dataFile = File('${directory.path}${Platform.pathSeparator}.tasks.json');
    output = [];
    errors = [];
    cli = YargsTaskListCli(
      dataFile: dataFile,
      writeOutput: output.add,
      writeError: errors.add,
    );
  });

  tearDown(() => directory.delete(recursive: true));

  test('adds a validated task and persists its complete JSON shape', () async {
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

  test('rejects an empty title through the task validator', () async {
    final exitCode = await cli.run(['add', '   ']);

    expect(exitCode, 64);
    expect(errors.single, contains('title'));
    expect(dataFile.existsSync(), isFalse);
  });

  test('rejects a description longer than the task validator allows', () async {
    final exitCode = await cli.run([
      'add',
      'Plan release',
      '--description=${'a' * 2001}',
    ]);

    expect(exitCode, 64);
    expect(errors.single, contains('description'));
  });

  test('deletes one task by its ID', () async {
    await cli.run(['add', 'First task']);
    await cli.run(['add', 'Second task']);
    output.clear();

    final exitCode = await cli.run(['delete', '1']);

    expect(exitCode, 0);
    expect(output, ['Deleted task 1.']);

    final document = jsonDecode(await dataFile.readAsString()) as Map;
    expect(document['tasks'], [
      {'id': 2, 'title': 'Second task', 'description': null, 'complete': false},
    ]);
  });

  test('deletes every completed task', () async {
    await cli.run(['add', 'Keep me']);
    await cli.run(['add', 'Remove me']);
    await cli.run(['update', '2', '--complete=true']);
    output.clear();

    final exitCode = await cli.run(['delete', '--completed']);

    expect(exitCode, 0);
    expect(output, ['Deleted 1 completed task.']);

    final document = jsonDecode(await dataFile.readAsString()) as Map;
    expect((document['tasks'] as List).single['id'], 1);
  });

  test('lists tasks by all, complete, and incomplete status', () async {
    await cli.run(['add', 'Open task']);
    await cli.run(['add', 'Finished task']);
    await cli.run(['update', '2', '--complete=true']);
    output.clear();

    final completeExitCode = await cli.run(['list', '--status=complete']);

    expect(completeExitCode, 0);
    expect(output, ['2 [complete] Finished task']);

    output.clear();
    final incompleteExitCode = await cli.run(['list', '--status=incomplete']);

    expect(incompleteExitCode, 0);
    expect(output, ['1 [incomplete] Open task']);

    output.clear();
    final allExitCode = await cli.run(['list']);

    expect(allExitCode, 0);
    expect(output, ['1 [incomplete] Open task', '2 [complete] Finished task']);
  });

  test('requires exactly one update flag', () async {
    await cli.run(['add', 'Original title']);
    output.clear();

    final noSelection = await cli.run(['update', '1']);
    final manySelections = await cli.run([
      'update',
      '1',
      '--title=New title',
      '--description=New description',
    ]);

    expect(noSelection, 64);
    expect(manySelections, 64);
    expect(errors, everyElement(contains('exactly one')));

    final document = jsonDecode(await dataFile.readAsString()) as Map;
    expect((document['tasks'] as List).single['title'], 'Original title');
  });

  test('updates title, description, and completion independently', () async {
    await cli.run(['add', 'Original title']);
    output.clear();

    expect(await cli.run(['update', '1', '--title=New title']), 0);
    expect(await cli.run(['update', '1', '--description=Details']), 0);
    expect(await cli.run(['update', '1', '--complete=true']), 0);

    expect(output, [
      'Updated task 1 title.',
      'Updated task 1 description.',
      'Updated task 1 completion state.',
    ]);

    final document = jsonDecode(await dataFile.readAsString()) as Map;
    expect(document['tasks'], [
      {
        'id': 1,
        'title': 'New title',
        'description': 'Details',
        'complete': true,
      },
    ]);
  });

  test('rejects deleting by ID and completed status in one command', () async {
    final exitCode = await cli.run(['delete', '1', '--completed']);

    expect(exitCode, 64);
    expect(errors.single, contains('either a task ID or --completed'));
  });

  test('rejects an option that belongs to another command', () async {
    final exitCode = await cli.run([
      'add',
      'Plan release',
      '--status=incomplete',
    ]);

    expect(exitCode, 64);
    expect(errors.single, contains('exactly one task title'));
    expect(dataFile.existsSync(), isFalse);
  });

  test('rejects an unsupported list status', () async {
    final exitCode = await cli.run(['list', '--status=archived']);

    expect(exitCode, 64);
    expect(errors.single, contains('all, complete, or incomplete'));
  });
}
