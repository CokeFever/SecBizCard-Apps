abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class ConnectionFailure extends Failure {
  const ConnectionFailure(super.message);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class GeneralFailure extends Failure {
  const GeneralFailure(super.message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}
