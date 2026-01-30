// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:fitgate_admin/theme/app_colors.dart';
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigate(context, route),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.white.withOpacity(0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isActive ? Border.all(color: Colors.white24, width: 1) : null,
          ),
          child: Row(
            children: [
              Icon(icon, color: isActive ? Colors.white : Colors.white70, size: 22),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white70,
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
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
      backgroundColor: const Color(0xFFf8fafc),
      body: SafeArea(
        child: Row(
          children: [
            Container(
              width: 260,
              height: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(2, 0),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.fitness_center, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'FitGate Admin',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _buildNavItem(context: context, icon: Icons.dashboard_rounded, label: 'Kontrolna ploča', route: '/dashboard'),
                  const SizedBox(height: 6),
                  _buildNavItem(context: context, icon: Icons.people_rounded, label: 'Članovi', route: '/members'),
                  const SizedBox(height: 6),
                  _buildNavItem(context: context, icon: Icons.lock_rounded, label: 'Ormari', route: '/lockers'),
                  const SizedBox(height: 6),
                  _buildNavItem(context: context, icon: Icons.history_rounded, label: 'Nedavna aktivnost', route: '/activity-logs'),
                  const SizedBox(height: 6),
                  // ...removed Podešavanja nav item...
                  const Spacer(),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _logout(context),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.logout_rounded, color: Colors.white70, size: 20),
                            SizedBox(width: 12),
                            Text(
                              'Odjava',
                              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
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
