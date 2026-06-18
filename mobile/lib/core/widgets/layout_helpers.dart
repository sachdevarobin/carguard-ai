import 'package:flutter/material.dart';

/// Forces [child] to use the parent's max width. Required inside [AlertDialog]
/// and nested [Column]s with [CrossAxisAlignment.start] so [Expanded] text wraps.
class FullWidth extends StatelessWidget {
  const FullWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: double.maxFinite, child: child);
  }
}

/// Scrollable [AlertDialog] body with reliable horizontal width.
class DialogBody extends StatelessWidget {
  const DialogBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.maxFinite,
      child: SingleChildScrollView(child: child),
    );
  }
}

/// Label stacked above value — avoids cramped side-by-side rows on phones.
class DetailField extends StatelessWidget {
  const DetailField({
    super.key,
    required this.label,
    required this.value,
    this.dense = false,
  });

  final String label;
  final String value;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: dense ? 6 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.3),
          ),
        ],
      ),
    );
  }
}
