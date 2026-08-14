
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/theam/theam_dart.dart';

class ErrorState extends StatelessWidget {
  final String message;
  const ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: LmsColors.error, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: LmsColors.error)),
          ],
        ),
      ),
    );
  }
}