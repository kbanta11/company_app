import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:algolia/algolia.dart';
import 'create_topic_dialog.dart';
import 'services/auth_services.dart';
import 'formatters/upper_case_formatter.dart';
import 'signin_page.dart';
import 'main.dart';
import 'group_page.dart';
import 'inbox_page.dart';
import 'services/database_services.dart';
import 'services/topic_services.dart';
import 'models/user_model.dart';
import 'models/group_model.dart';
import 'providers/auth_providers.dart';


final teams = ['All NFL', 'Fantasy Football', 'Arizona Cardinals','Atlanta Falcons','Baltimore Ravens','Buffalo Bills','Carolina Panthers','Chicago Bears','Cincinnati Bengals','Cleveland Browns','Dallas Cowboys','Denver Broncos','Detroit Lions','Green Bay Packers','Houston Texans','Indianapolis Colts','Jacksonville Jaguars','Kansas City Chiefs','Las Vegas Raiders','Los Angeles Chargers','Los Angeles Rams','Miami Dolphins','Minnesota Vikings','New England Patriots','New Orleans Saints','New York Giants','New York Jets','Philadelphia Eagles','Pittsburgh Steelers','San Francisco 49ers','Seattle Seahawks','Tampa Bay Buccaneers','Tennessee Titans','Washington Football Team'];

class Topic extends StateNotifier<TopicModel?> {
  Topic(): super(null);
  void updateTopic(TopicModel topic) => state = topic;
}

final topicProvider = StateNotifierProvider.autoDispose<Topic, TopicModel?>((_) => Topic());

class ErrorText extends StateNotifier<String?> {
  ErrorText(): super(null);
  void updateErrorText(String? text) => state = text;
}
final codeErrorProvider = StateNotifierProvider.autoDispose<ErrorText, String?>((_) => ErrorText());

class JoinGroupPage extends ConsumerWidget {
  TextEditingController codeController = TextEditingController();
  final TextEditingController _topicSearchController = TextEditingController();

  @override
  build(BuildContext context, ScopedReader watch) {
    TopicModel? topic = watch(topicProvider);
    String? codeErrorText = watch(codeErrorProvider);
    AppUser? currentUser = watch(appUserProvider).data?.value;
    final notifier = watch(topicProvider.notifier);
    final codeErrorNotifier = watch(codeErrorProvider.notifier);
    return Scaffold(
      backgroundColor: const Color(0xFF262626),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF262626),
        title: const Text('Join Group', style: TextStyle(color: Colors.white)),
      ),
      drawer: Drawer(
          child: ListView(
              children: [
                ListTile(
                    title: const Text('Home'),
                    onTap: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MyHomePage()));
                    }
                ),
                ListTile(
                    title: const Text('Join Another Group'),
                    onTap: () {

                    }
                ),
                ListTile(
                    title: const Text('Messages'),
                    onTap: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => InboxPage()));
                    }
                ),
                ListTile(
                    title: const Text('Logout'),
                    onTap: () async {
                      await AuthService().logout();
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SignInPage()));
                    }
                ),
              ]
          )
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Choose a topic:', style: TextStyle(fontSize: 18, color: Colors.white)),
            const SizedBox(height: 10),
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
                      print(snap.hits);
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
                            notifier.updateTopic(topic);
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
                        notifier.updateTopic(topic);
                        _topicSearchController.text = topic.topic ?? '';
                        print('Topic: ${topic.topic} / ${_topicSearchController.text}');
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
                          notifier.updateTopic(topic);
                          _topicSearchController.text = topic.topic ?? '';
                        }
                      },
                    );
                  }
              )
            ),
            TextButton(
              style: TextButton.styleFrom(backgroundColor: Colors.blueGrey),
              child: const Text('Find A Group', style: TextStyle(fontSize: 16, color: Colors.white)),
              onPressed: () async {
                if(topic != null && topic != '') {
                  Group newGroup = await DatabaseServices().joinGroup(topic: topic, userId: currentUser?.id, userName: currentUser?.name);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => GroupPage(group: newGroup,)));
                }
              },
            ),
            const SizedBox(height: 15),
            const Text('-- or --', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 15),
            const Text('Join group by code:', style: TextStyle(fontSize: 18, color: Colors.white)),
            const SizedBox(height: 5),
            Container(
              decoration: const BoxDecoration(
                border: Border.fromBorderSide(BorderSide(width: 1.5, color: Colors.white))
              ),
              width: 200,
              child: TextField(
                decoration: InputDecoration(
                  counterText: "",
                  errorText: codeErrorText,
                ),
                inputFormatters: [
                  UpperCaseTextFormatter()
                ],
                textAlign: TextAlign.center,
                maxLength: 8,
                style: const TextStyle(fontSize: 18, color: Colors.white),
                controller: codeController,
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(backgroundColor: Colors.blueGrey),
              child: const Text('Join Group', style: TextStyle(fontSize: 16, color: Colors.white)),
              onPressed: () async {
                codeErrorNotifier.updateErrorText(null);
                if(codeController.value.text.length == 8) {
                  Group? newGroup = await DatabaseServices().joinGroupWithCode(code: codeController.value.text, userId: currentUser?.id);
                  if(newGroup == null) {
                    codeErrorNotifier.updateErrorText('Group is full or was not found!');
                  } else {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => GroupPage(group: newGroup,)));
                  }
                }
              },
            )
          ]
        )
      )
    );
  }
}