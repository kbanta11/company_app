import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_services.dart';
import '../services/database_services.dart';
import '../models/user_model.dart';


final authServicesProvider = Provider<AuthService>((ref) => AuthService());
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServicesProvider).authStateChange;
});
final appUserProvider = StreamProvider<AppUser?>((ref) {
  String? uid = ref.watch(authStateProvider).data?.value?.uid;
  if(uid != null) {
    return DatabaseServices().streamUserData(uid);
  }
  return const Stream.empty();
});

