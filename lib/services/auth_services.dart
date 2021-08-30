import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import './database_services.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;


  Stream<User?> get authStateChange => _auth.authStateChanges();

  Future<String> signUp({String? email, String? topic, String? name, String? code}) async {
    try {
      final String password = generatePassword();
      UserCredential userCred = await _auth.createUserWithEmailAndPassword(email: email!, password: password);
      String userId = userCred.user!.uid;
      await _auth.sendPasswordResetEmail(email: email);
      await DatabaseServices().createUser(id: userId, firstTopic: topic, email: email, name: name, code: code);
      return 'User Created!';
    } on FirebaseAuthException catch (e) {
      return e.message!;
    }
  }

  Future<String> signIn({String? email, String? password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email!, password: password!);
      return 'Successfully Signed In!';
    } on FirebaseAuthException catch (e) {
      return e.code;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> resetPassword(String? email) async {
    if(email == null) {
      return;
    }
    await _auth.sendPasswordResetEmail(email: email);
  }
}



String generatePassword({
  bool letter = true,
  bool isNumber = true,
  bool isSpecial = true,
}) {
  const length = 20;
  const letterLowerCase = "abcdefghijklmnopqrstuvwxyz";
  const letterUpperCase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  const number = '0123456789';
  const special = '@#%^*>\$@?/[]=+';

  String chars = "";
  if (letter) chars += '$letterLowerCase$letterUpperCase';
  if (isNumber) chars += '$number';
  if (isSpecial) chars += '$special';


  return List.generate(length, (index) {
    final indexRandom = Random.secure().nextInt(chars.length);
    return chars [indexRandom];
  }).join('');
}