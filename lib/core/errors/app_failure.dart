/// A typed failure that carries copy safe to show to users.
class AppFailure implements Exception {
  const AppFailure(this.message, {this.code});

  final String message;
  final String? code;

  factory AppFailure.from(Object error) {
    if (error is AppFailure) return error;
    return const AppFailure(
      'Something went wrong. Please try again.',
      code: 'unknown',
    );
  }

  @override
  String toString() => message;
}
