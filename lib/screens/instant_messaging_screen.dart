import 'package:flutter/material.dart';

class InstantMessagingScreen extends StatelessWidget {
  const InstantMessagingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> messagesList =
        List.generate(10, (index) => 'Message $index');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Instant Messaging'),
      ),
      body: ListView.builder(
        itemCount: messagesList.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(messagesList[index]),
          );
        },
      ),
    );
  }
}
