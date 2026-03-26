import 'package:flutter/material.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: const Color(0xFF1E1E2E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SizedBox(height: 24),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Trading Systems',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Divider(height: 1),
          SizedBox(height: 8),
          _SidebarItem(title: 'Dashboard', icon: Icons.dashboard),
          _SidebarItem(title: 'Performance', icon: Icons.show_chart),
          _SidebarItem(title: 'Risk Analysis', icon: Icons.warning_amber),
          _SidebarItem(title: 'Settings', icon: Icons.settings),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SidebarItem({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(title),
      dense: true,
      onTap: () {},
    );
  }
}