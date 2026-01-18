// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';
import 'members_screen.dart';
import 'lockers_screen.dart';
import 'activity_logs_screen.dart';

/// Shell layout with sidebar navigation
class ShellScreen extends StatelessWidget {
  final String currentRoute;

  const ShellScreen({super.key, required this.currentRoute});

  void _navigate(BuildContext context, String route) {
    if (route == currentRoute) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await AuthService().logout();
    } catch (_) {
      // ignore logout errors
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    Navigator.of(context).pushReplacementNamed('/');
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String route,
  }) {
    final isActive = currentRoute == route;
    return InkWell(
      onTap: () => _navigate(context, route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue[800] : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (currentRoute) {
      case '/members':
        return const MembersScreen();
      case '/lockers':
        return const LockersScreen();
      case '/activity-logs':
        return const ActivityLogsScreen();
      case '/dashboard':
      default:
        return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Row(
          children: [
            Container(
              width: 260,
              height: double.infinity,
              color: Colors.blue[900],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.fitness_center, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      const Text(
                        'FitGate',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildNavItem(
                    context: context,
                    icon: Icons.dashboard_outlined,
                    label: 'Kontrolna Ploča',
                    route: '/dashboard',
                  ),
                  const SizedBox(height: 8),
                  _buildNavItem(
                    context: context,
                    icon: Icons.people_outline,
                    label: 'Članovi',
                    route: '/members',
                  ),
                  const SizedBox(height: 8),
                  _buildNavItem(
                    context: context,
                    icon: Icons.lock_outline,
                    label: 'Ormari',
                    route: '/lockers',
                  ),
                  const SizedBox(height: 8),
                  _buildNavItem(
                    context: context,
                    icon: Icons.history,
                    label: 'Nedavna Aktivnost',
                    route: '/activity-logs',
                  ),
                  const SizedBox(height: 8),
                  _buildNavItem(
                    context: context,
                    icon: Icons.settings_outlined,
                    label: 'Podešavanja',
                    route: '/admin-settings',
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => _logout(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.logout, color: Colors.white70, size: 20),
                          SizedBox(width: 12),
                          Text(
                            'Odjava',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }
}
