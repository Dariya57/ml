import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          TextFormField(decoration: const InputDecoration(labelText: 'Возраст')),
          TextFormField(decoration: const InputDecoration(labelText: 'Вес (кг)')),
          TextFormField(decoration: const InputDecoration(labelText: 'Рост (см)')),
          ElevatedButton(onPressed: () {}, child: const Text('Сохранить'))
        ],
      ),
    );
  }
}