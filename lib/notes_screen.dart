import 'package:flutter/material.dart';
import 'package:drivenotes/login.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          ),
        ],
      ),
      body: const Center(child: Text('Welcome to Notes Screen!')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement note creation
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
