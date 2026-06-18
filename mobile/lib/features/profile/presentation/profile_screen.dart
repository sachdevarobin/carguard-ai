import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.person, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 12),
          const Text('Guest User', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Text('Sign in coming soon', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          const _ProfileTile(icon: Icons.workspace_premium_outlined, title: 'Premium Reports', subtitle: '₹199 per AI report'),
          const _ProfileTile(icon: Icons.support_agent_outlined, title: 'Expert Reviews', subtitle: '₹499–₹999'),
          const _ProfileTile(icon: Icons.privacy_tip_outlined, title: 'Privacy & Disclaimer', subtitle: 'AI-assisted guidance only'),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
