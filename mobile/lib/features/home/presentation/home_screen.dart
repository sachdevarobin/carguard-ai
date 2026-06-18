import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspections = ref.watch(inspectionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CarGuard AI'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Start New Inspection',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Guided AI-assisted PDI before you accept delivery.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => context.push('/inspection/new'),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Begin Inspection'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Recent Inspections',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          inspections.when(
            data: (items) {
              if (items.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No inspections yet. Start your first delivery check.'),
                  ),
                );
              }
              return Column(
                children: items.take(5).map((item) {
                  final date = DateFormat('MMM d, yyyy').format(item.createdAt);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(item.displayName),
                      subtitle: Text('$date • ${item.status}'),
                      trailing: Text(
                        item.score == null ? '--' : '${item.score}/100',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: item.score != null && item.score! >= 90
                              ? AppColors.success
                              : AppColors.warning,
                        ),
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
                }).toList(),
              );
            },
            loading: () => const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )),
            error: (error, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Could not load inspections',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Something went wrong reading local data. Try restarting the app.',
                      style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    Text('Error: $error', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
