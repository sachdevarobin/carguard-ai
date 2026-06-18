import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspections = ref.watch(inspectionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Past Reports')),
      body: inspections.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No reports yet.'));
          }

          final grouped = <String, List<dynamic>>{};
          for (final item in items) {
            final key = DateFormat('MMMM yyyy').format(item.createdAt);
            grouped.putIfAbsent(key, () => []).add(item);
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: grouped.entries.expand((entry) sync* {
              yield Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 8),
                child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
              );
              for (final item in entry.value) {
                yield Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(item.displayName),
                    subtitle: Text(item.status == 'completed' ? 'Inspection complete' : 'In progress'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          item.score == null ? '--' : '${item.score}/100',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (item.score != null && item.score! < 95)
                          Text(
                            'Accept with clarifications',
                            style: TextStyle(fontSize: 11, color: AppColors.warning),
                          ),
                      ],
                    ),
                    onTap: () {
                      if (item.status == 'completed') {
                        context.push('/inspection/${item.id}/results');
                      } else {
                        context.push('/inspection/${item.id}/progress');
                      }
                    },
                  ),
                );
              }
            }).toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
