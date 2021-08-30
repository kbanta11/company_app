import 'auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_services.dart';
import '../models/group_model.dart';

final userGroupsProvider = StreamProvider<List<Group>?>((ref) {
  User? user = ref.watch(authStateProvider).data?.value;
  return DatabaseServices().getAllGroups(userId: user?.uid);
});

