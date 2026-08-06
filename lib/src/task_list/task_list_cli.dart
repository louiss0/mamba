import 'dart:io';

import 'package:arg_parser/arg_parser.dart';

import 'task.dart';
import 'task_service.dart';
import 'task_store.dart';
import 'task_text_validator.dart';

/// A task-list command-line application backed by a project-local JSON file.
final class TaskListCli {
  TaskListCli({
    File? dataFile,
    void Function(String)? writeOutput,
    void Function(String)? writeError,
  }) : _service = TaskService(TaskStore(dataFile ?? File('.tasks.json'))),
       _writeOutput = writeOutput ?? _writeStandardOutput,
       _writeError = writeError ?? _writeStandardError;

  final TaskService _service;
  final void Function(String) _writeOutput;
  final void Function(String) _writeError;
  final TaskTextValidator _textValidator = TaskTextValidator();

  static final _parser = ArgParser(
    commands: [
      ArgCommand(
        'add',
        options: {'description': const StringOption()},
        positionals: const [ArgPositional('title', required: true)],
      ),
      ArgCommand(
        'delete',
        options: {'completed': const BooleanOption()},
        positionals: const [ArgPositional('id')],
      ),
      ArgCommand(
        'update',
        options: {
          'title': const StringOption(),
          'description': const StringOption(),
          'complete': const StringOption(choices: {'true', 'false'}),
        },
        positionals: const [ArgPositional('id', required: true)],
      ),
      ArgCommand(
        'list',
        options: {
          'status': const StringOption(
            defaultValue: 'all',
            choices: {'all', 'complete', 'incomplete'},
          ),
        },
      ),
    ],
  );

  /// Runs one task-list command and returns a process-compatible exit code.
  Future<int> run(List<String> tokens) async {
    switch (_parser.parse(tokens)) {
      case ArgParseFailure(:final error):
        return _usageError(error.message);
      case ArgParseSuccess(:final arguments):
        return switch (arguments.commandPath.single) {
          'add' => _addTask(arguments),
          'delete' => _deleteTasks(arguments),
          'update' => _updateTask(arguments),
          'list' => _listTasks(arguments),
          _ => _usageError('Choose add, delete, update, or list.'),
        };
    }
  }

  Future<int> _addTask(ArgArguments arguments) async {
    late final String title;
    switch (_textValidator.validateTitle(arguments.positional('title')!)) {
      case TaskTextValid(:final value):
        title = value;
      case TaskTextInvalid(:final message):
        return _usageError(message);
    }

    String? description;
    if (arguments.string('description') case final descriptionInput?) {
      switch (_textValidator.validateDescription(descriptionInput)) {
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

  Future<int> _deleteTasks(ArgArguments arguments) async {
    final id = arguments.positional('id');
    final deleteCompleted = arguments.flag('completed')!;
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
    final deleted = await _service.deleteTask(taskId);
    if (deleted case TaskOperationFailure(:final message)) {
      return _storageError(message);
    }

    _writeOutput('Deleted task $taskId.');
    return 0;
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

  Future<int> _updateTask(ArgArguments arguments) async {
    late final int taskId;
    switch (_parseTaskId(arguments.positional('id')!)) {
      case final int value:
        taskId = value;
      case null:
        return _usageError('Task ID must be a positive whole number.');
    }

    late final TaskUpdate update;
    switch (_parseUpdate(arguments)) {
      case TaskUpdateSuccess(update: final updateValue):
        update = updateValue;
      case TaskUpdateFailure(:final message):
        return _usageError(message);
    }

    switch (await _service.updateTask(taskId, update)) {
      case TaskOperationSuccess():
        _writeOutput('Updated task $taskId ${update.label}.');
        return 0;
      case TaskOperationFailure(:final message):
        return _storageError(message);
    }
  }

  Future<int> _listTasks(ArgArguments arguments) async {
    final status = switch (arguments.string('status')) {
      'all' => TaskStatus.all,
      'complete' => TaskStatus.complete,
      'incomplete' => TaskStatus.incomplete,
      _ => TaskStatus.all,
    };
    late final List<Task> tasks;
    switch (await _service.listTasks(status)) {
      case TaskOperationSuccess(:final value):
        tasks = value;
      case TaskOperationFailure(:final message):
        return _storageError(message);
    }
    if (tasks.isEmpty) {
      _writeOutput('No tasks.');
      return 0;
    }

    for (final task in tasks) {
      final state = task.complete ? 'complete' : 'incomplete';
      _writeOutput('${task.id} [$state] ${task.title}');
      if (task.description case final description?) {
        _writeOutput('  $description');
      }
    }
    return 0;
  }

  TaskUpdateResult _parseUpdate(ArgArguments arguments) {
    final selections = <TaskUpdate>[];
    if (arguments.string('title') case final title?) {
      switch (_textValidator.validateTitle(title)) {
        case TaskTextValid(:final value):
          selections.add(TaskTitleUpdate(value));
        case TaskTextInvalid(:final message):
          return TaskUpdateResult.failure(message);
      }
    }
    if (arguments.string('description') case final description?) {
      switch (_textValidator.validateDescription(description)) {
        case TaskTextValid(:final value):
          selections.add(TaskDescriptionUpdate(value));
        case TaskTextInvalid(:final message):
          return TaskUpdateResult.failure(message);
      }
    }
    if (arguments.string('complete') case final complete?) {
      selections.add(TaskCompletionUpdate(complete == 'true'));
    }

    if (selections.length != 1) {
      return const TaskUpdateResult.failure(
        'Choose exactly one update flag: --title, --description, or --complete.',
      );
    }
    return TaskUpdateResult.success(selections.single);
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

sealed class TaskUpdateResult {
  const TaskUpdateResult();

  const factory TaskUpdateResult.success(TaskUpdate update) = TaskUpdateSuccess;
  const factory TaskUpdateResult.failure(String message) = TaskUpdateFailure;
}

final class TaskUpdateSuccess extends TaskUpdateResult {
  const TaskUpdateSuccess(this.update);

  final TaskUpdate update;
}

final class TaskUpdateFailure extends TaskUpdateResult {
  const TaskUpdateFailure(this.message);

  final String message;
}
