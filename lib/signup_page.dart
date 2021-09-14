import 'package:algolia/algolia.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:the_company_app/services/topic_services.dart';

import 'create_topic_dialog.dart';
import 'main.dart';
import 'models/group_model.dart';
import 'services/database_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:email_validator/email_validator.dart';
import 'services/auth_services.dart';
import 'formatters/upper_case_formatter.dart';
import 'signin_page.dart';

class NewUserData {
  TopicModel? topic;
  String? email;
  bool showEmailError;
  String? name;
  String? password;
  String? confirmPass;
  int currentStep;
  String? groupCode;
  String? groupCodeError;
  bool? joinGroupByCode;
  bool isLoading;

  NewUserData({
    this.topic,
    this.email,
    this.showEmailError = false,
    this.isLoading = false,
    this.name,
    this.password,
    this.confirmPass,
    this.currentStep = 0,
    this.groupCode,
    this.groupCodeError,
    this.joinGroupByCode = false
  });

  NewUserData copyWith({TopicModel? topic, String? email, bool? emailError, String? name, String? password, String? confirmPassword, int? currentStep, String? groupCode, String? groupCodeError, bool? joinGroupByCode, bool isLoading = false}) {
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
      joinGroupByCode: joinGroupByCode ?? this.joinGroupByCode,
      isLoading: isLoading,
    );
  }
}

class NewUserDataNotifier extends StateNotifier<NewUserData> {
  NewUserDataNotifier() : super(NewUserData());

  changeTopic(TopicModel topic) => state = state.copyWith(topic: topic);
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
  toggleLoading() => state = state.copyWith(isLoading: !(state.isLoading));
}

final signupProvider = StateNotifierProvider<NewUserDataNotifier, NewUserData>((_) => NewUserDataNotifier());
final teams = ['All NFL', 'Fantasy Football', 'Arizona Cardinals','Atlanta Falcons','Baltimore Ravens','Buffalo Bills','Carolina Panthers','Chicago Bears','Cincinnati Bengals','Cleveland Browns','Dallas Cowboys','Denver Broncos','Detroit Lions','Green Bay Packers','Houston Texans','Indianapolis Colts','Jacksonville Jaguars','Kansas City Chiefs','Las Vegas Raiders','Los Angeles Chargers','Los Angeles Rams','Miami Dolphins','Minnesota Vikings','New England Patriots','New Orleans Saints','New York Giants','New York Jets','Philadelphia Eagles','Pittsburgh Steelers','San Francisco 49ers','Seattle Seahawks','Tampa Bay Buccaneers','Tennessee Titans','Washington Football Team'];

class SignUpPage extends ConsumerWidget {
  TextEditingController _topicSearchController = TextEditingController();

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
                  const Text('Sign Up', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
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
                              notifier.setGroupCodeError('Group does not exist or is full!');
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
                          //toggle loading indicator
                          notifier.toggleLoading();
                          ////Create account and send password reset email
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
                          FirebaseAnalytics().logSignUp(signUpMethod: 'email_and_password');
                          notifier.toggleLoading();
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MyHomePage()));
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
                              style: TextButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
                              child: userData.isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator()) :  Text(userData.currentStep == 2 ? 'Create Account' : 'Continue', style: const TextStyle(fontSize: 18, color: Colors.black)),
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
                            title: const Text('Choose a Topic', style: TextStyle(color: Colors.white)),
                            content: Column(
                                children: [
                                  SizedBox(
                                      width: 300,
                                      child:TypeAheadField(
                                          textFieldConfiguration: TextFieldConfiguration(
                                              controller: _topicSearchController,
                                              style: const TextStyle(color: Colors.white),
                                              decoration: const InputDecoration(
                                                border: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                                                disabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                                                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                                                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                                              )
                                          ),
                                          suggestionsCallback: (pattern) async {
                                            Algolia algolia = Application.algolia;
                                            AlgoliaQuery query = algolia.instance.index('company-topics').query(pattern);
                                            return await query.getObjects().then((AlgoliaQuerySnapshot snap) {
                                              if(snap.hasHits) {
                                                List<TopicModel?> results = snap.hits.map((AlgoliaObjectSnapshot objSnap) {
                                                  //print('Obj Data: ${objSnap.data}');
                                                  return TopicModel(
                                                    id: objSnap.data['objectID'],
                                                    topic: objSnap.data['topic'],
                                                    subTopics: List.castFrom(objSnap.data['sub-topics'] as List),
                                                  );
                                                }).toList();
                                                results.add(TopicModel(topic: 'Create a New Topic'));
                                                return results;
                                              }
                                              return [];
                                            });
                                          },
                                          itemBuilder: (context, suggestion) {
                                            var topic = suggestion as TopicModel;
                                            if(topic.topic == 'Create a New Topic') {
                                              return ListTile(
                                                  leading: const Icon(Icons.add_circle_outline_rounded),
                                                  title: Text(topic.topic ?? ''),
                                                  onTap: () async {
                                                    TopicModel? topic = await showDialog(
                                                        context: context,
                                                        builder: (context) {
                                                          return CreateTopicDialog(_topicSearchController);
                                                        }
                                                    );
                                                    if(topic != null) {
                                                      notifier.changeTopic(topic);
                                                      _topicSearchController.text = topic.topic ?? '';
                                                    }
                                                  }
                                              );
                                            }
                                            return ListTile(
                                              title: Text(topic.topic ?? ''),
                                            );
                                          },
                                          onSuggestionSelected: (suggestion) {
                                            if(suggestion != null) {
                                              try {
                                                TopicModel topic = suggestion as TopicModel;
                                                if(topic.topic == 'Create a New Topic') {
                                                  return;
                                                }
                                                notifier.changeTopic(topic);
                                                _topicSearchController.text = topic.topic ?? '';
                                              } catch (e) {
                                                return;
                                              }
                                            }
                                          },
                                        noItemsFoundBuilder: (context) {
                                            return ListTile(
                                              leading: const Icon(Icons.add_circle_outline_rounded),
                                              title: const Text('Create a New Topic'),
                                              onTap: () async {
                                                TopicModel? topic = await showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return CreateTopicDialog(_topicSearchController);
                                                  }
                                                );
                                                if(topic != null) {
                                                  notifier.changeTopic(topic);
                                                  _topicSearchController.text = topic.topic ?? '';
                                                }
                                              },
                                            );
                                        },
                                      )
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