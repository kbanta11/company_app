import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/direct_message_models.dart';
import '../services/database_services.dart';
import 'auth_providers.dart';

final inboxProvider = StreamProvider<List<Conversation>>((ref) {
  User? user = ref.watch(authStateProvider).data?.value;
  return DatabaseServices().streamUserInbox(user?.uid);
});