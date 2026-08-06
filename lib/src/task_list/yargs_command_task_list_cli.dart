import 'dart:io';

import 'package:arg_parser/arg_parser.dart';

import 'task.dart';
import 'task_service.dart';
import 'task_store.dart';
import 'task_text_validator.dart';

/// A task-list CLI that demonstrates [YargsCommandRuntime].
final class YargsCommandTaskListCli {
  YargsCommandTaskListCli({
    File? dataFile,
    void Function(String)? writeOutput,
    void Function(String)? writeError,
  }) : _service = TaskService(
         TaskStore(dataFile ?? File('.yargs_command_tasks.json')),
       ),
       _writeOutput = writeOutput ?? _writeStandardOutput,
       _writeError = writeError ?? _writeStandardError {
    _runtime = YargsCommandRuntime(
      commands: [
        YargsCommand(
          'add',
          description: 'Create a task.',
          positionals: const [YargsPositional('title', required: true)],
          options: const [
            YargsCommandOption.string(
              'description',
              description: 'Optional task detail.',
            ),
          ],
          handler: _handleAdd,
        ),
        YargsCommand(
          'delete',
          description: 'Delete one task or every completed task.',
          positionals: const [YargsPositional('id')],
          options: const [
            YargsCommandOption.boolean(
              'completed',
              description: 'Delete every completed task.',
            ),
          ],
          handler: _handleDelete,
        ),
        YargsCommand(
          'update',
          description: 'Update exactly one task field.',
          positionals: const [YargsPositional('id', required: true)],
          options: const [
            YargsCommandOption.string('title', description: 'New task title.'),
            YargsCommandOption.string(
              'description',
              description: 'New task detail.',
            ),
            YargsCommandOption.string(
              'complete',
              choices: {'true', 'false'},
              description: 'Set completion to true or false.',
            ),
          ],
          handler: _handleUpdate,
        ),
        YargsCommand(
          'list',
          description: 'List tasks.',
          options: const [
            YargsCommandOption.string(
              'status',
              defaultValue: 'all',
              choices: {'all', 'complete', 'incomplete'},
              description: 'Filter by task status.',
            ),
          ],
          handler: _handleList,
        ),
      ],
    );
  }

  final TaskService _service;
  final void Function(String) _writeOutput;
  final void Function(String) _writeError;
  final TaskTextValidator _textValidator = TaskTextValidator();
  late final YargsCommandRuntime _runtime;
  var _handlerExitCode = 0;

  /// Runs one task-list command and returns a process-compatible exit code.
  Future<int> run(List<String> tokens) async {
    _handlerExitCode = 0;
    final outcome = await _runtime.run(tokens);
    if (outcome case YargsCommandFailure(:final message)) {
      return _usageError(message);
    }
    return _handlerExitCode;
  }

  Future<void> _handleAdd(YargsCommandArguments arguments) async {
    _handlerExitCode = await _addTask(arguments);
  }

  Future<void> _handleDelete(YargsCommandArguments arguments) async {
    _handlerExitCode = await _deleteTasks(arguments);
  }

  Future<void> _handleUpdate(YargsCommandArguments arguments) async {
    _handlerExitCode = await _updateTask(arguments);
  }

  Future<void> _handleList(YargsCommandArguments arguments) async {
    _handlerExitCode = await _listTasks(arguments);
  }

  Future<int> _addTask(YargsCommandArguments arguments) async {
    late final String title;
    switch (_textValidator.validateTitle(arguments.positional('title')!)) {
      case TaskTextValid(:final value):
        title = value;
      case TaskTextInvalid(:final message):
        return _usageError(message);
    }

    String? description;
    if (arguments['description'] case final String input) {
      switch (_textValidator.validateDescription(input)) {
        case TaskTextValid(:final value):
          description = value;
        case TaskTextInvalid(:final message):
          return _usageError(message);
      }
    }

    switch (await _service.addTask(title: title, description: description)) {
      case TaskOperationSuccess(:final value):
        _writeOutput('Added task ${value.id}: ${value.title}');
        return 0;
      case TaskOperationFailure(:final message):
        return _storageError(message);
    }
  }

  Future<int> _deleteTasks(YargsCommandArguments arguments) async {
    final id = arguments.positional('id');
    final deleteCompleted = arguments.flag('completed') == true;
    if (id != null && deleteCompleted) {
      return _usageError('Choose either a task ID or --completed, not both.');
    }
    if (id == null && !deleteCompleted) {
      return _usageError('Provide a task ID or use --completed.');
    }
    if (deleteCompleted) return _deleteCompletedTasks();

    final taskId = _parseTaskId(id!);
    if (taskId == null) {
      return _usageError('Task ID must be a positive whole number.');
    }
    switch (await _service.deleteTask(taskId)) {
      case TaskOperationSuccess():
        _writeOutput('Deleted task $taskId.');
        return 0;
      case TaskOperationFailure(:final message):
        return _storageError(message);
    }
  }

  Future<int> _deleteCompletedTasks() async {
    switch (await _service.deleteCompletedTasks()) {
      case TaskOperationSuccess(:final value):
        final noun = value == 1 ? 'task' : 'tasks';
        _writeOutput('Deleted $value completed $noun.');
        return 0;
      case TaskOperationFailure(:final message):
        return _storageError(message);
    }
  }

  Future<int> _updateTask(YargsCommandArguments arguments) async {
    final taskId = _parseTaskId(arguments.positional('id')!);
    if (taskId == null) {
      return _usageError('Task ID must be a positive whole number.');
    }
    final update = _createUpdate(arguments);
    if (update == null) return 64;

    switch (await _service.updateTask(taskId, update)) {
      case TaskOperationSuccess():
        _writeOutput('Updated task $taskId ${update.label}.');
        return 0;
      case TaskOperationFailure(:final message):
        return _storageError(message);
    }
  }

  TaskUpdate? _createUpdate(YargsCommandArguments arguments) {
    final updates = <TaskUpdate>[];
    if (arguments['title'] case final String title) {
      switch (_textValidator.validateTitle(title)) {
        case TaskTextValid(:final value):
          updates.add(TaskTitleUpdate(value));
        case TaskTextInvalid(:final message):
          _usageError(message);
          return null;
      }
    }
    if (arguments['description'] case final String description) {
      switch (_textValidator.validateDescription(description)) {
        case TaskTextValid(:final value):
          updates.add(TaskDescriptionUpdate(value));
        case TaskTextInvalid(:final message):
          _usageError(message);
          return null;
      }
    }
    if (arguments['complete'] case final String complete) {
      updates.add(TaskCompletionUpdate(complete == 'true'));
    }
    if (updates.length != 1) {
      _usageError(
        'Choose exactly one update flag: --title, --description, or --complete.',
      );
      return null;
    }
    return updates.single;
  }

  Future<int> _listTasks(YargsCommandArguments arguments) async {
    final status = switch (arguments['status']) {
      'all' => TaskStatus.all,
      'complete' => TaskStatus.complete,
      'incomplete' => TaskStatus.incomplete,
      _ => TaskStatus.all,
    };
    switch (await _service.listTasks(status)) {
      case TaskOperationSuccess(:final value):
        if (value.isEmpty) {
          _writeOutput('No tasks.');
          return 0;
        }
        for (final task in value) {
          final state = task.complete ? 'complete' : 'incomplete';
          _writeOutput('${task.id} [$state] ${task.title}');
          if (task.description case final description?) {
            _writeOutput('  $description');
          }
        }
        return 0;
      case TaskOperationFailure(:final message):
        return _storageError(message);
    }
  }

  int? _parseTaskId(String input) {
    final id = int.tryParse(input);
    return id == null || id < 1 ? null : id;
  }

  int _usageError(String message) {
    _writeError(message);
    return 64;
  }

  int _storageError(String message) {
    _writeError(message);
    return 1;
  }

  static void _writeStandardOutput(String message) => stdout.writeln(message);

  static void _writeStandardError(String message) => stderr.writeln(message);
}
