import 'package:flutter/material.dart';

import '../../View_model/auth_result_model.dart';

class ExamSelectionScreen extends StatefulWidget {
  final AuthResultModel authResult;

  const ExamSelectionScreen({super.key, required this.authResult});

  @override
  State<ExamSelectionScreen> createState() => _ExamSelectionScreenState();
}

class _ExamSelectionScreenState extends State<ExamSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    final user = widget.authResult.user;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.yellow,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.authResult.isNewUser ? 'New Account Created' : 'Welcome Back',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text('ID: ${user.id}'),
                Text('Name: ${user.name ?? "N/A"}'),
                Text('Email: ${user.email}'),
                Text('Role: ${user.role}'),
           
              ],
            ),
          ),
        ),
      ),
    );
  }
}