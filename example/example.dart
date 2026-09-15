import 'dart:convert';
import 'dart:io';

import 'package:mamba/mamba.dart';

Future<void> main(List<String> args) {
  final store = TaskStore(
    File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}mamba_tasks.json',
    ),
  );
  return Executor('task-cli', 'Manage a persisted task list.', '1.0.0', [
    CreateTaskCommand(store),
    ListTaskCommand(store),
    ReadTaskCommand(store),
    UpdateTaskCommand(store),
    DeleteTaskCommand(store),
    CompleteTaskCommand(store),
    ReopenTaskCommand(store),
    ExportTasksCommand(store),
    CompletionTaskCommand(),
  ]).create().execute(args);
}

final class Task {
  const new({
    required this.id,
    required this.title,
    required this.description,
    required this.completed,
  });

  final int id;
  final String title;
  final String description;
  final bool completed;

  Task copyWith({String? title, String? description, bool? completed}) => Task(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    completed: completed ?? this.completed,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'completed': completed,
  };

  factory fromJson(Map<String, dynamic> json) => Task(
    id: json['id'] as int,
    title: json['title'] as String,
    description: json['description'] as String,
    completed: json['completed'] as bool? ?? false,
  );
}

final class TaskStore {
  const new(this.file);

  final File file;

  ({int nextId, List<Task> tasks}) _read() {
    if (!file.existsSync()) return (nextId: 1, tasks: <Task>[]);

    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded case {
        'nextId': final int nextId,
        'tasks': final List<dynamic> taskData,
      }) {
        return (
          nextId: nextId,
          tasks: taskData
              .map((item) => Task.fromJson(item as Map<String, dynamic>))
              .toList(),
        );
      }
      throw const FormatException('Unexpected task-list structure.');
    } on FileSystemException catch (error) {
      throw MambaException('Could not read the task list: ${error.message}.');
    } on FormatException catch (error) {
      throw MambaException('Could not read the task list: ${error.message}');
    } on TypeError {
      throw MambaException('Could not read the task list: invalid task data.');
    }
  }

  List<Task> readAll() => List.unmodifiable(_read().tasks);

  void _write(int nextId, List<Task> tasks) {
    try {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        JsonEncoder.withIndent('  ').convert({
          'nextId': nextId,
          'tasks': tasks.map((task) => task.toJson()).toList(),
        }),
        flush: true,
      );
    } on FileSystemException catch (error) {
      throw MambaException('Could not save the task list: ${error.message}.');
    }
  }

  Task? find(int id) => readAll().where((task) => task.id == id).firstOrNull;

  Task add(String title, String description) {
    final document = _read();
    final task = Task(
      id: document.nextId,
      title: title,
      description: description,
      completed: false,
    );
    _write(document.nextId + 1, [...document.tasks, task]);
    return task;
  }

  Task update(int id, {String? title, String? description, bool? completed}) {
    final document = _read();
    final index = document.tasks.indexWhere((task) => task.id == id);
    if (index < 0) throw MambaException('Task $id was not found.');

    final updated = document.tasks[index].copyWith(
      title: title,
      description: description,
      completed: completed,
    );
    final tasks = [...document.tasks]..[index] = updated;
    _write(document.nextId, tasks);
    return updated;
  }

  void delete(int id) {
    final document = _read();
    final tasks = document.tasks.where((task) => task.id != id).toList();
    if (tasks.length == document.tasks.length) {
      throw MambaException('Task $id was not found.');
    }
    _write(document.nextId, tasks);
  }

  void setCompleted(int id, bool completed) => update(id, completed: completed);
}

String _validatedText(String field, String value) {
  final text = value.trim();
  if (text.isEmpty) throw MambaException('$field must not be empty.');
  return text;
}

int _taskId(ParsedInputs inputs, NormalPositional input) =>
    int.parse(inputs.valueOf(input));

final class CreateTaskCommand extends Command {
  new(this.store) : super(options: [title, description]);

  static final title = StringOption.required(
    'title',
    description: 'Task title.',
    regex: RegExp(r'.+'),
  );
  static final description = StringOption.required(
    'description',
    description: 'Task description.',
    regex: RegExp(r'.+'),
  );

  final TaskStore store;

  @override
  String get name => 'create';

  @override
  String get shortDescription => 'Create a task.';

  @override
  String run(ParsedInputs inputs, List<String> args) {
    final task = store.add(
      _validatedText('title', inputs.valueOf(title)),
      _validatedText('description', inputs.valueOf(description)),
    );
    return 'Created task ${task.id}: ${task.title}';
  }
}

enum TaskStatus { all, completed, pending }

final class ListTaskCommand extends Command {
  new(this.store) : super(options: [status]);

  static final status = ChoiceOption.withDefault(
    'status',
    choices: TaskStatus.values,
    defaultValue: TaskStatus.all,
    description: 'Filter tasks by completion status.',
  );

  final TaskStore store;

  @override
  String get name => 'list';

  @override
  String get shortDescription =>
      'List tasks, optionally filtered by completion.';

  @override
  String run(ParsedInputs inputs, List<String> args) {
    final statusValue = inputs.valueOf(status);
    final tasks = store.readAll().where((task) {
      return switch (statusValue) {
        TaskStatus.all => true,
        TaskStatus.completed => task.completed,
        TaskStatus.pending => !task.completed,
      };
    }).toList();
    if (tasks.isEmpty) return 'No matching tasks.';
    return tasks
        .map(
          (task) =>
              '${task.completed ? '[x]' : '[ ]'} ${task.id}: ${task.title} — ${task.description}',
        )
        .join('\n');
  }
}

abstract class TaskIdCommand extends Command {
  new() : super(mandatoryPositionals: [id]);

  static final id = NormalPositional('id', regExp: RegExp(r'\d+'));
}

final class ReadTaskCommand extends TaskIdCommand {
  new(this.store);

  final TaskStore store;

  @override
  String get name => 'read';

  @override
  String get shortDescription => 'Read one task.';

  @override
  String run(ParsedInputs inputs, List<String> args) {
    final task = store.find(_taskId(inputs, TaskIdCommand.id));
    if (task == null) throw MambaException('Task not found.');
    return '${task.completed ? '[x]' : '[ ]'} ${task.id}: ${task.title}\n${task.description}';
  }
}

final class UpdateTaskCommand extends Command {
  new(this.store) : super(mandatoryPositionals: [id], pairedOptions: [changes]);

  static final id = NormalPositional('id', regExp: RegExp(r'\d+'));
  static final title = PairStringOption(
    'title',
    regex: RegExp(r'.+'),
    description: 'Replacement title.',
  );
  static final description = PairStringOption(
    'description',
    regex: RegExp(r'.+'),
    description: 'Replacement description.',
  );
  static final changes = PairedOptions<String>.required([title, description]);

  final TaskStore store;

  @override
  String get name => 'update';

  @override
  String get shortDescription => 'Update a task.';

  @override
  String run(ParsedInputs inputs, List<String> args) {
    final idValue = _taskId(inputs, id);
    final changesValues = inputs.valueOf(changes);
    store.update(
      idValue,
      title: _validatedText('title', changesValues['title']!),
      description: _validatedText('description', changesValues['description']!),
    );
    return 'Updated task $idValue.';
  }
}

final class DeleteTaskCommand extends TaskIdCommand {
  new(this.store);

  final TaskStore store;

  @override
  String get name => 'delete';

  @override
  String get shortDescription => 'Delete a task.';

  @override
  String run(ParsedInputs inputs, List<String> args) {
    final id = _taskId(inputs, TaskIdCommand.id);
    store.delete(id);
    return 'Deleted task $id.';
  }
}

enum TaskExportFormat { json, text }

final class ExportTasksCommand extends Command {
  new(this.store) : super(options: [format, output]);

  static final format = ChoiceOption.required(
    'format',
    choices: TaskExportFormat.values,
    description: 'Choose JSON or text output.',
  );
  static final output = StringOption.required(
    'output',
    description: 'Write output to this path.',
  );

  final TaskStore store;

  @override
  String get name => 'export';

  @override
  String get shortDescription => 'Export every task.';

  @override
  String run(ParsedInputs inputs, List<String> args) {
    final path = inputs.valueOf(output);
    final content = switch (inputs.valueOf(format)) {
      TaskExportFormat.json => JsonEncoder.withIndent(
        '  ',
      ).convert(store.readAll().map((task) => task.toJson()).toList()),
      TaskExportFormat.text =>
        store.readAll().map((task) => '${task.id}: ${task.title}').join('\n'),
    };
    File(path).writeAsStringSync(content);
    return 'Exported tasks to $path.';
  }
}

final class CompleteTaskCommand extends TaskIdCommand {
  new(this.store);

  final TaskStore store;

  @override
  String get name => 'complete';

  @override
  String get shortDescription => 'Mark a task as completed.';

  @override
  String run(ParsedInputs inputs, List<String> args) {
    final id = _taskId(inputs, TaskIdCommand.id);
    store.setCompleted(id, true);
    return 'Completed task $id.';
  }
}

final class ReopenTaskCommand extends TaskIdCommand {
  new(this.store);

  final TaskStore store;

  @override
  String get name => 'reopen';

  @override
  String get shortDescription => 'Mark a task as pending.';

  @override
  String run(ParsedInputs inputs, List<String> args) {
    final id = _taskId(inputs, TaskIdCommand.id);
    store.setCompleted(id, false);
    return 'Reopened task $id.';
  }
}

final class CompletionTaskCommand extends CompletionCommand {
  new() : super(options: [output]);

  static final output = StringOption.required(
    'output',
    description: 'Write the Carapace spec to this path.',
  );

  @override
  String get name => 'completion';

  @override
  String get shortDescription => 'Generate the Carapace completion spec.';

  @override
  String run(ParsedInputs inputs, List<String> args) {
    final path = inputs.valueOf(output);
    CarapaceSpecWriter(
      CarapaceSpecConverter(registryRecord),
      outputPath: path,
    ).write();
    return 'Wrote Carapace spec to $path.';
  }
}
