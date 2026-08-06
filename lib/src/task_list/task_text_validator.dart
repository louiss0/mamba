import 'package:acanthis/acanthis.dart' as acanthis;

/// Validates and normalizes task titles and descriptions.
final class TaskTextValidator {
  static final _titleSchema = acanthis.string().min(1).max(120);
  static final _descriptionSchema = acanthis.string().min(1).max(2000);

  TaskTextValidation validateTitle(String input) {
    final normalized = input.trim();
    final result = _titleSchema.tryParse(normalized);
    if (!result.success) {
      return const TaskTextInvalid(
        'The task title must contain 1 to 120 characters.',
      );
    }
    return TaskTextValid(result.value);
  }

  TaskTextValidation validateDescription(String input) {
    final normalized = input.trim();
    final result = _descriptionSchema.tryParse(normalized);
    if (!result.success) {
      return const TaskTextInvalid(
        'The task description must contain 1 to 2000 characters.',
      );
    }
    return TaskTextValid(result.value);
  }
}

sealed class TaskTextValidation {
  const TaskTextValidation();
}

final class TaskTextValid extends TaskTextValidation {
  const TaskTextValid(this.value);

  final String value;
}

final class TaskTextInvalid extends TaskTextValidation {
  const TaskTextInvalid(this.message);

  final String message;
}
