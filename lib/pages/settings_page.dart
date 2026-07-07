import 'package:flutter/material.dart';
import 'theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('设置', style: TextStyle(color: kTextSecondary)));
  }
}
