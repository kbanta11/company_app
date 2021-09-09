import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/group_model.dart';
import 'services/database_services.dart';

class LoadingIndicator extends StateNotifier<bool> {
  LoadingIndicator(): super(false);
  void toggleLoading () => state = !state;
}

final loadingProvider = StateNotifierProvider.autoDispose<LoadingIndicator, bool>((_) => LoadingIndicator());

class CreateTopicDialog extends ConsumerWidget {
  TextEditingController _topicController;
  TextEditingController _subTopicController = TextEditingController();

  CreateTopicDialog(this._topicController);

  @override
  build(BuildContext context, ScopedReader watch) {
    bool _loadingIndicator = watch(loadingProvider);
    final notifier = watch(loadingProvider.notifier);
    return SimpleDialog(
      title: const Center(child: Text('Create New Topic')),
      contentPadding: const EdgeInsets.all(15),
      children: [
        const Text('You are creating a new topic!', textAlign: TextAlign.center,),
        Center(child: Text(_topicController.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20))),
        const SizedBox(height: 10),
        const Text('Add some sub-topics?\n(separated by a semicolon ";")', textAlign: TextAlign.center),
        TextField(
          controller: _subTopicController,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(backgroundColor: const Color(0xFF262626),),
              child: _loadingIndicator ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator()) : const Text('Create Topic', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                if(_loadingIndicator) {
                  return;
                }
                if(_topicController.text == '') {
                  return;
                }
                List<String> subTopics = _subTopicController.text.split(";").map((item) => item.trim()).toList();
                print('Creating group: ${_topicController.text} / Sub-topics: $subTopics');
                notifier.toggleLoading();
                TopicModel? topic = await DatabaseServices().createTopic(topic: _topicController.text, subTopics: subTopics);
                notifier.toggleLoading();
                Navigator.of(context).pop(topic);
              },
            )
          ],
        )
      ],
    );
  }
}