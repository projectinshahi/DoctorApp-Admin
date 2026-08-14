
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/theam/theam_dart.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback? onAdd;
  const SectionTitle(this.title, {required this.count, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: LmsColors.textDark,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: LmsColors.textDark.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: LmsColors.textDark,
            ),
          ),
        ),
        const Spacer(),
        if (onAdd != null)
          TextButton.icon(
            onPressed: onAdd,
            style: TextButton.styleFrom(
              foregroundColor: LmsColors.primary,
              backgroundColor: LmsColors.primarySoft,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'Add Exam Type',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
          ),
      ],
    );
  }
}
