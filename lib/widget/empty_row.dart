
import 'package:flutter/cupertino.dart';

import '../core/theam/theam_dart.dart';

class EmptyRow extends StatelessWidget {
  final String text;
  const EmptyRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(text, style: const TextStyle(color: LmsColors.textGrey, fontSize: 13)),
    );
  }
}
