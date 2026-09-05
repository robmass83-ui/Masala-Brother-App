import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_models.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repo = AuthRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final authSessionProvider = StreamProvider<AuthSession>((ref) {
  return ref.watch(authRepositoryProvider).watchSession();
});
