import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository repository;

  RegisterUseCase(this.repository);

  Future<User> call(String name, String email, String password, String role) async {
    return await repository.register(name, email, password, role);
  }
}
