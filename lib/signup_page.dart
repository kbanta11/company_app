import 'main.dart';
import 'services/database_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:email_validator/email_validator.dart';
import 'services/auth_services.dart';
import 'formatters/upper_case_formatter.dart';
import 'signin_page.dart';

class NewUserData {
  String? topic;
  String? email;
  bool showEmailError;
  String? name;
  String? password;
  String? confirmPass;
  int currentStep;
  String? groupCode;
  String? groupCodeError;
  bool? joinGroupByCode;

  NewUserData({
    this.topic,
    this.email,
    this.showEmailError = false,
    this.name,
    this.password,
    this.confirmPass,
    this.currentStep = 0,
    this.groupCode,
    this.groupCodeError,
    this.joinGroupByCode = false
  });

  NewUserData copyWith({String? topic, String? email, bool? emailError, String? name, String? password, String? confirmPassword, int? currentStep, String? groupCode, String? groupCodeError, bool? joinGroupByCode}) {
    return NewUserData(
      topic: topic ?? this.topic,
      email: email ?? this.email,
      showEmailError: emailError ?? this.showEmailError,
      name: name ?? this.name,
      password: password ?? this.password,
      confirmPass: confirmPassword ?? this.confirmPass,
      currentStep: currentStep ?? this.currentStep,
      groupCode: groupCode ?? this.groupCode,
      groupCodeError: groupCodeError,
      joinGroupByCode: joinGroupByCode ?? this.joinGroupByCode
    );
  }
}

class NewUserDataNotifier extends StateNotifier<NewUserData> {
  NewUserDataNotifier() : super(NewUserData());

  changeTopic(String topic) => state = state.copyWith(topic: topic);
  changeGroupCode(String? code) {
    state.groupCode = code;
    state.joinGroupByCode = false;
    return state = state;
  }
  setGroupCodeError(String? error) {
    state.groupCodeError = error;
    return state = state;
  }
  changeEmail(String email) => state = state.copyWith(email: email);
  setEmailError(bool val) => state = state.copyWith(emailError: val);
  changeName(String name) => state = state.copyWith(name: name);
  changePass(String pass) => state = state.copyWith(password: pass);
  changeConfirmPass(String pass) => state = state.copyWith(confirmPassword: pass);
  changeStep(int step) => state = state.copyWith(currentStep: step);
  setJoinGroupByCode(bool val) => state = state.copyWith(joinGroupByCode: val);
}

final signupProvider = StateNotifierProvider<NewUserDataNotifier, NewUserData>((_) => NewUserDataNotifier());
final teams = ['All NFL', 'Fantasy Football', 'Arizona Cardinals','Atlanta Falcons','Baltimore Ravens','Buffalo Bills','Carolina Panthers','Chicago Bears','Cincinnati Bengals','Cleveland Browns','Dallas Cowboys','Denver Broncos','Detroit Lions','Green Bay Packers','Houston Texans','Indianapolis Colts','Jacksonville Jaguars','Kansas City Chiefs','Las Vegas Raiders','Los Angeles Chargers','Los Angeles Rams','Miami Dolphins','Minnesota Vikings','New England Patriots','New Orleans Saints','New York Giants','New York Jets','Philadelphia Eagles','Pittsburgh Steelers','San Francisco 49ers','Seattle Seahawks','Tampa Bay Buccaneers','Tennessee Titans','Washington Football Team'];

class SignUpPage extends ConsumerWidget {
  @override
  build(BuildContext context, ScopedReader watch) {
    FirebaseAnalytics().setCurrentScreen(screenName: 'signup_page');
    NewUserData userData = watch(signupProvider);
    NewUserDataNotifier notifier = watch(signupProvider.notifier);
    return Scaffold(
      backgroundColor: const Color(0xFF262626),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(40),
          child: SingleChildScrollView(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Stepper(
                      currentStep: userData.currentStep,
                      onStepContinue: () async {
                        if(userData.currentStep == 0) {
                          if(userData.topic == null && (userData.groupCode == null || userData.groupCode!.length != 8)) {
                            return;
                          }
                          //check if group code exists and if matches existing group
                          if(userData.groupCode != null && userData.groupCode!.length == 8) {
                            if(await DatabaseServices().checkGroupExistsByCode(userData.groupCode!)) {
                              //if group does exist, set join by code flag to true and continue
                              notifier.setJoinGroupByCode(true);
                              print('Join by group: ${userData.joinGroupByCode}');
                              notifier.setGroupCodeError(null);
                            } else {
                              //if group code is entered, but doesn't exist, show error on field and return
                              print('setting error');
                              notifier.setGroupCodeError('Group does not exist!');
                              return;
                            }
                          }

                          notifier.changeStep(userData.currentStep + 1);
                        }
                        if(userData.currentStep == 1) {
                          if(userData.email == null) {
                            return;
                          }
                          if(!EmailValidator.validate(userData.email ?? '')) {
                            notifier.setEmailError(true);
                            return;
                          }
                          notifier.setEmailError(false);
                          notifier.changeStep(userData.currentStep + 1);
                        }
                        if(userData.currentStep == 2) {
                          if(userData.name == null || userData.name == '') {
                            return;
                          }
                          ////Create account and send password reset email
                          //
                          print('Join by code??? - ${userData.joinGroupByCode}: ${userData.groupCode}');
                          if(userData.joinGroupByCode ?? false) {
                            //signup with code
                            print('joining by group code');
                            await AuthService().signUp(email: userData.email, name: userData.name, code: userData.groupCode);
                          } else {
                            //signup with topic
                            print('joining with topic');
                            await AuthService().signUp(email: userData.email, name: userData.name, topic: userData.topic);
                          }

                          //FirebaseAnalytics().logSignUp(signUpMethod: 'email_and_password');
                          //Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MyHomePage()));
                        }
                      },
                      onStepCancel: () {
                        if(userData.currentStep == 0) {
                          return;
                        }
                        notifier.changeStep(userData.currentStep - 1);
                      },
                      controlsBuilder: (BuildContext context, {onStepContinue, onStepCancel}) {
                        return Row(
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(backgroundColor: Colors.blueGrey,),
                              child: Text(userData.currentStep == 2 ? 'Create Account' : 'Continue', style: const TextStyle(fontSize: 18, color: Colors.white)),
                              onPressed: onStepContinue,
                            ),
                            userData.currentStep != 0 ? TextButton(
                              child: const Text('Back', style: TextStyle(fontSize: 18, color: Colors.white)),
                              onPressed: onStepCancel,
                            ) : Container(),
                          ],
                        );
                      },
                      steps: [
                        Step(
                            title: const Text('Choose a Team', style: TextStyle(color: Colors.white)),
                            content: Column(
                                children: [
                                  DropdownButton(
                                    dropdownColor: Colors.black,
                                      value: userData.topic,
                                      onChanged: (String? value) {
                                        notifier.changeTopic(value ?? userData.topic!);
                                      },
                                      style: const TextStyle(color: Colors.white),
                                      items: teams.map((String item) => DropdownMenuItem(
                                        child: Text(item),
                                        value: item,
                                      )).toList()
                                  ),
                                  const SizedBox(height: 5),
                                  const Text('-- OR --', style: TextStyle(color: Colors.white)),
                                  const SizedBox(height: 5),
                                  TextField(
                                    decoration: InputDecoration(
                                      hintText: 'Enter Group Code',
                                      hintStyle: const TextStyle(color: Colors.grey),
                                      errorText: userData.groupCodeError,
                                      counterStyle: const TextStyle(color: Colors.white),
                                    ),
                                    inputFormatters: [
                                      UpperCaseTextFormatter()
                                    ],
                                    style: const TextStyle(fontSize: 18, color: Colors.white),
                                    maxLength: 8,
                                    onChanged: (value) {
                                      notifier.changeGroupCode(value);
                                    },
                                  ),
                                ]
                            )
                        ),
                        Step(
                            title: const Text('Enter your email', style: TextStyle(color: Colors.white)),
                            subtitle: const Text('We\'ll email you to set your password!', style: TextStyle(color: Colors.grey)),
                            content: TextField(
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                                  errorText: userData.showEmailError ? 'Enter a valid email address' : null
                              ),
                              onChanged: (value) {
                                notifier.changeEmail(value);
                              },
                            )
                        ),
                        Step(
                            title: const Text('Enter your first name and last initial', style: TextStyle(color: Colors.white)),
                            content: TextField(
                              decoration: const InputDecoration(
                                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                              ),
                              style: const TextStyle(color: Colors.white),
                              onChanged: (value) {
                                notifier.changeName(value);
                              },
                            )
                        ),
                      ]
                  ),
                  Column(
                      children: [
                        const Text('Already have an account?', style: TextStyle(color: Colors.white)),
                        TextButton(
                          style: TextButton.styleFrom(textStyle: const TextStyle(fontSize: 18)),
                          child: const Text('Sign In', style: TextStyle(color: Colors.white)),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => SignInPage()));
                          },
                        )
                      ]
                  )
                ]
            )
          ),
        )
      ),
    );
  }
}