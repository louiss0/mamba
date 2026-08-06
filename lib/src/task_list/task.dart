/// A persisted task in a task list.
final class Task {
  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.complete,
  });

  final int id;
  final String title;
  final String? description;
  final bool complete;

  Task copyWith({String? title, String? description, bool? complete}) => Task(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    complete: complete ?? this.complete,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'complete': complete,
  };

  static TaskDecode decodeJson(Object? source) {
    if (source is! Map) {
      return const TaskDecodeFailure('A task must be a JSON object.');
    }

    final id = source['id'];
    final title = source['title'];
    final description = source['description'];
    final complete = source['complete'];
    if (id is! int || id < 1) {
      return const TaskDecodeFailure('A task ID must be a positive integer.');
    }
    if (title is! String) {
      return const TaskDecodeFailure('A task title must be a string.');
    }
    if (description != null && description is! String) {
      return const TaskDecodeFailure(
        'A task description must be a string or null.',
      );
    }
    if (complete is! bool) {
      return const TaskDecodeFailure(
        'A task completion value must be Boolean.',
      );
    }

    return TaskDecodeSuccess(
      Task(id: id, title: title, description: description, complete: complete),
    );
  }
}

sealed class TaskDecode {
  const TaskDecode();
}

final class TaskDecodeSuccess extends TaskDecode {
  const TaskDecodeSuccess(this.task);

  final Task task;
}

final class TaskDecodeFailure extends TaskDecode {
  const TaskDecodeFailure(this.message);

  final String message;
}

/// The property and normalized value that should replace part of a [Task].
sealed class TaskUpdate {
  const TaskUpdate();

  String get label;

  Task applyTo(Task task);
}

final class TaskTitleUpdate extends TaskUpdate {
  const TaskTitleUpdate(this.title);

  final String title;

  @override
  String get label => 'title';

  @override
  Task applyTo(Task task) => task.copyWith(title: title);
}

final class TaskDescriptionUpdate extends TaskUpdate {
  const TaskDescriptionUpdate(this.description);

  final String description;

  @override
  String get label => 'description';

  @override
  Task applyTo(Task task) => task.copyWith(description: description);
}

final class TaskCompletionUpdate extends TaskUpdate {
  const TaskCompletionUpdate(this.complete);

  final bool complete;

  @override
  String get label => 'completion state';

  @override
  Task applyTo(Task task) => task.copyWith(complete: complete);
}
