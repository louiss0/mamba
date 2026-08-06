import 'dart:io';

import 'package:arg_parser/arg_parser.dart';

import 'task.dart';
import 'task_service.dart';
import 'task_store.dart';
import 'task_text_validator.dart';

/// A task-list command-line application backed by a project-local JSON file.
final class YargsTaskListCli {
  YargsTaskListCli({
    File? dataFile,
    void Function(String)? writeOutput,
    void Function(String)? writeError,
  }) : _service = TaskService(TaskStore(dataFile ?? File('.yargs_tasks.json'))),
       _writeOutput = writeOutput ?? _writeStandardOutput,
       _writeError = writeError ?? _writeStandardError;

  final TaskService _service;
  final void Function(String) _writeOutput;
  final void Function(String) _writeError;
  final TaskTextValidator _textValidator = TaskTextValidator();

  static const _parser = YargsParser();
  static const _commandConfiguration = YargsParserConfiguration(
    duplicateArgumentsArray: false,
    parsePositionalNumbers: false,
    unknownOptionsAsArgs: true,
  );

  static const _addOptions = YargsParserOptions(
    key: {'description': null},
    string: ['description'],
    configuration: _commandConfiguration,
  );
  static const _deleteOptions = YargsParserOptions(
    boolean: ['completed'],
    key: {'completed': null},
    configuration: _commandConfiguration,
  );
  static const _updateOptions = YargsParserOptions(
    key: {'title': null, 'description': null, 'complete': null},
    string: ['title', 'description', 'complete'],
    configuration: _commandConfiguration,
  );
  static const _listOptions = YargsParserOptions(
    key: {'status': null},
    string: ['status'],
    defaultValues: {'status': 'all'},
    configuration: _commandConfiguration,
  );

  /// Runs one task-list command and returns a process-compatible exit code.
  Future<int> run(List<String> tokens) async {
    if (tokens.isEmpty) {
      return _usageError('Choose add, delete, update, or list.');
    }

    final command = tokens.first;
    final arguments = _parseCommand(command, tokens.skip(1).toList());
    if (arguments == null) return 64;

    return switch (command) {
      'add' => _addTask(arguments),
      'delete' => _deleteTasks(arguments),
      'update' => _updateTask(arguments),
      'list' => _listTasks(arguments),
      _ => _usageError(
        'Unknown task command "$command". Choose add, delete, update, or list.',
      ),
    };
  }

  Map<String, Object?>? _parseCommand(String command, List<String> tokens) {
    final options = switch (command) {
      'add' => _addOptions,
      'delete' => _deleteOptions,
      'update' => _updateOptions,
      'list' => _listOptions,
      _ => null,
    };
    if (options == null) return <String, Object?>{};

    final result = _parser.detailed(tokens, options);
    if (result.error != null) {
      _usageError('Invalid arguments for task_list $command.');
      return null;
    }
    return result.argv;
  }

  Future<int> _addTask(Map<String, Object?> arguments) async {
    final title = _singlePositional(arguments, 'task title');
    if (title == null) return 64;

    late final String validatedTitle;
    switch (_textValidator.validateTitle(title)) {
      case TaskTextValid(:final value):
        validatedTitle = value;
      case TaskTextInvalid(:final message):
        return _usageError(message);
    }

    final descriptionInput = arguments['description'];
    if (descriptionInput != null && descriptionInput is! String) {
      return _usageError('The task description must be text.');
    }

    String? description;
    if (descriptionInput case final String value) {
      switch (_textValidator.validateDescription(value)) {
        case TaskTextValid(:final value):
          description = value;
        case TaskTextInvalid(:final message):
          return _usageError(message);
      }
    }

    switch (await _service.addTask(
      title: validatedTitle,
      description: description,
    )) {
      case TaskOperationSuccess(:final value):
        _writeOutput('Added task ${value.id}: ${value.title}');
        return 0;
      case TaskOperationFailure(:final message):
        return _storageError(message);
    }
  }

  Future<int> _deleteTasks(Map<String, Object?> arguments) async {
    final positionals = _positionals(arguments);
    if (positionals == null) return 64;
    if (positionals.length > 1) {
      return _usageError('Delete accepts one task ID or --completed.');
    }

    final id = positionals.isEmpty ? null : positionals.single;
    final deleteCompleted = arguments['completed'] == true;
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

  Future<int> _updateTask(Map<String, Object?> arguments) async {
    final id = _singlePositional(arguments, 'task ID');
    if (id == null) return 64;
    final taskId = _parseTaskId(id);
    if (taskId == null) {
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

  Future<int> _listTasks(Map<String, Object?> arguments) async {
    final positionals = _positionals(arguments);
    if (positionals == null) return 64;
    if (positionals.isNotEmpty) {
      return _usageError('List does not accept positional arguments.');
    }

    final status = switch (arguments['status']) {
      'all' => TaskStatus.all,
      'complete' => TaskStatus.complete,
      'incomplete' => TaskStatus.incomplete,
      _ => null,
    };
    if (status == null) {
      return _usageError('Choose --status all, complete, or incomplete.');
    }

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

  TaskUpdateResult _parseUpdate(Map<String, Object?> arguments) {
    final selections = <TaskUpdate>[];
    final title = arguments['title'];
    if (title != null) {
      if (title is! String) {
        return const TaskUpdateResult.failure('The task title must be text.');
      }
      switch (_textValidator.validateTitle(title)) {
        case TaskTextValid(:final value):
          selections.add(TaskTitleUpdate(value));
        case TaskTextInvalid(:final message):
          return TaskUpdateResult.failure(message);
      }
    }

    final description = arguments['description'];
    if (description != null) {
      if (description is! String) {
        return const TaskUpdateResult.failure(
          'The task description must be text.',
        );
      }
      switch (_textValidator.validateDescription(description)) {
        case TaskTextValid(:final value):
          selections.add(TaskDescriptionUpdate(value));
        case TaskTextInvalid(:final message):
          return TaskUpdateResult.failure(message);
      }
    }

    final complete = arguments['complete'];
    if (complete != null) {
      if (complete is! String || (complete != 'true' && complete != 'false')) {
        return const TaskUpdateResult.failure(
          'Use --complete=true or --complete=false.',
        );
      }
      selections.add(TaskCompletionUpdate(complete == 'true'));
    }

    if (selections.length != 1) {
      return const TaskUpdateResult.failure(
        'Choose exactly one update flag: --title, --description, or --complete.',
      );
    }
    return TaskUpdateResult.success(selections.single);
  }

  String? _singlePositional(
    Map<String, Object?> arguments,
    String description,
  ) {
    final values = _positionals(arguments);
    if (values == null) return null;
    if (values.isEmpty) {
      _usageError('Provide a $description.');
      return null;
    }
    if (values.length > 1) {
      _usageError('Provide exactly one $description.');
      return null;
    }
    return values.single;
  }

  List<String>? _positionals(Map<String, Object?> arguments) {
    final values = arguments['_'];
    if (values is! List || values.any((value) => value is! String)) {
      _usageError('Task arguments must be text.');
      return null;
    }
    return values.cast<String>();
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
