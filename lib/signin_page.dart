import 'package:company_app/signup_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/auth_services.dart';
import 'main.dart';

class SignInData {
  String? email;
  String? password;
  String? resetEmail;
  String? resetEmailError;
  String? emailError;
  String? passwordError;

  SignInData({
    this.email,
    this.password,
    this.resetEmail,
    this.resetEmailError,
    this.emailError,
    this.passwordError
  });

  SignInData copyWith({String? email, String? password, String? resetEmail, String? resetEmailError, String? emailError, String? passwordError}) {
    return SignInData(
      email: email ?? this.email,
      password: password ?? this.password,
      resetEmail: resetEmail,
      resetEmailError: resetEmailError,
      emailError: emailError,
      passwordError: passwordError
    );
  }
}

class SignInNotifier extends StateNotifier<SignInData> {
  SignInNotifier() : super(SignInData());

  changeEmail(String email) => state = state.copyWith(email: email);
  changePass(String pass) => state = state.copyWith(password: pass);
  changeResetEmail(String? email) => state = state.copyWith(resetEmail: email);
  changeResetEmailError(String? error) => state = state.copyWith(resetEmailError: error);
  changeEmailError(String? errorMessage) => state = state.copyWith(emailError: errorMessage);
  changePasswordError(String? errorMessage) => state = state.copyWith(passwordError: errorMessage);
}

final signinProvider = StateNotifierProvider<SignInNotifier, SignInData>((_) => SignInNotifier());

class SignInPage extends ConsumerWidget {
  @override
  build(BuildContext context, ScopedReader watch) {
    FirebaseAnalytics().setCurrentScreen(screenName: 'signin_page');
    SignInData signInData = watch(signinProvider);
    SignInNotifier notifier = watch(signinProvider.notifier);
    return Scaffold(
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Card(
            elevation: 10,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(25))),
            child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        decoration: InputDecoration(hintText: 'Email', errorText: signInData.emailError),
                        onChanged: (value) {
                          notifier.changeEmail(value);
                        },
                      ),
                      TextField(
                        decoration: InputDecoration(hintText: 'Password', errorText: signInData.passwordError),
                        obscureText: true,
                        onChanged: (value) {
                          notifier.changePass(value);
                        },
                      ),
                      TextButton(
                          style: TextButton.styleFrom(backgroundColor: Colors.blueGrey),
                          child: const Text('Sign In', style: TextStyle(fontSize: 18, color: Colors.white),),
                          onPressed: () async {
                            if(signInData.email == null) {
                              notifier.changeEmailError('Please enter an email address!');
                              return;
                            }
                            if(signInData.password == null) {
                              notifier.changePasswordError('Please enter your password!');
                              return;
                            }
                            String signinResponse = await AuthService().signIn(email: signInData.email, password: signInData.password);
                            if(signinResponse == 'wrong-password') {
                              notifier.changePasswordError('This password is incorrect!');
                              return;
                            }
                            if(signinResponse == 'user-not-found') {
                              notifier.changeEmailError('User not found with this email!');
                              return;
                            }
                            if(signinResponse == 'too-many-requests') {
                              await showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
                                    content: const Text('You have tried logging in too many times unsuccessfully! If you have forgotten your password, press the "Forgot Password" button', textAlign: TextAlign.center,),
                                    actions: [TextButton(child: Text('OK'), onPressed: () {
                                      Navigator.of(context).pop();
                                    })],
                                  );
                                }
                              );
                              return;
                            }
                            //print('Sign In Response: $signinResponse');
                            FirebaseAnalytics().logLogin(loginMethod: 'email_and_password');
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MyHomePage()));
                          }
                      ),
                      const SizedBox(height: 5),
                      TextButton(
                          child: const Text('Forgot your password?'),
                          onPressed: () async {
                            await showDialog(
                              context: context,
                              builder: (context) {
                                return ResetPasswordDialog();
                              }
                            );
                            notifier.changeResetEmailError(null);
                            notifier.changeResetEmail(null);
                          }
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        child: const Text('Sign Up!', style: TextStyle(fontSize: 16)),
                        onPressed: () {
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SignUpPage()));
                        },
                      )
                    ]
                )
            ),
          ),
        ),
      ),
    );
  }
}

class ResetPasswordDialog extends ConsumerWidget {

  @override
  build(BuildContext context, ScopedReader watch) {
    SignInData signInData = watch(signinProvider);
    SignInNotifier notifier = watch(signinProvider.notifier);
    return SimpleDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(15),
      title: const Text('Reset Password'),
      children: [
        TextField(
          decoration: InputDecoration(hintText: 'Enter your Email', errorText: signInData.resetEmailError),
          onChanged: (value) {
            notifier.changeResetEmail(value);
          },
        ),
        TextButton(
          style: TextButton.styleFrom(backgroundColor: Colors.blueGrey),
          child: const Text('Reset Password', style: TextStyle(color: Colors.white),),
          onPressed: () async {
            //print('Reset Email: ${signInData.resetEmail}');
            if(signInData.resetEmail == null) {
              notifier.changeResetEmailError('Enter the email address of your account!');
              return;
            }
            try {
              FirebaseAnalytics().logEvent(name: 'reset_password');
              await AuthService().resetPassword(signInData.resetEmail);
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    content: const Text('A password reset email has been sent!'),
                    actions: [
                      TextButton(
                        child: const Text('Ok'),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      )
                    ],
                  );
                }
              );
            } on FirebaseAuthException catch (e) {
              if(e.code == 'invalid-email') {
                notifier.changeResetEmailError('Email entered is not a valid email address');
              }
              if(e.code == 'user-not-found') {
                notifier.changeResetEmailError('We don\'t have an account for this email address!');
              }
            }
          },
        )
      ],
    );
  }
}