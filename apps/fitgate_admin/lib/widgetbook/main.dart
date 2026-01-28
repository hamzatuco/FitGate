import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:fitgate_admin/widgets/stat_card.dart';
import 'package:fitgate_admin/widgets/status_badge.dart';
import 'package:fitgate_admin/widgets/locker_tile.dart';
import 'package:fitgate_admin/widgets/confirm_dialog.dart';
import 'package:fitgate_admin/widgets/loading_view.dart';
import 'package:fitgate_admin/widgets/empty_view.dart';

void main() {
  runApp(const FitGateWidgetbook());
}

class FitGateWidgetbook extends StatelessWidget {
  const FitGateWidgetbook({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      directories: [
        WidgetbookCategory(
          name: 'Widgets',
          children: [
            WidgetbookComponent(
              name: 'StatCard',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (context) => SizedBox(
                    width: 320,
                    child: const StatCard(
                      title: 'Active Members',
                      value: '128',
                      icon: Icons.group,
                      color: Colors.blue,
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Warning',
                  builder: (context) => SizedBox(
                    width: 320,
                    child: const StatCard(
                      title: 'Out of Service',
                      value: '5',
                      icon: Icons.warning,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'StatusBadge',
              useCases: [
                WidgetbookUseCase(
                  name: 'Active',
                  builder: (context) => const StatusBadge(status: 'active'),
                ),
                WidgetbookUseCase(
                  name: 'Occupied',
                  builder: (context) => const StatusBadge(status: 'occupied'),
                ),
                WidgetbookUseCase(
                  name: 'Out of Service',
                  builder: (context) => const StatusBadge(status: 'out_of_service'),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'LockerTile',
              useCases: [
                WidgetbookUseCase(
                  name: 'Free',
                  builder: (context) => SizedBox(
                    width: 160,
                    child: LockerTile(
                      lockerNumber: 'A-12',
                      sector: 'A',
                      status: 'free',
                      onTap: () {},
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Occupied',
                  builder: (context) => SizedBox(
                    width: 160,
                    child: LockerTile(
                      lockerNumber: 'B-05',
                      sector: 'B',
                      status: 'occupied',
                      assignedMember: 'Marija Horvat',
                      onTap: () {},
                      onForceRelease: () {},
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Out of Service',
                  builder: (context) => SizedBox(
                    width: 160,
                    child: LockerTile(
                      lockerNumber: 'C-02',
                      sector: 'C',
                      status: 'out_of_service',
                      onTap: () {},
                      onMarkOutOfService: () {},
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'ConfirmDialog',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (context) => Center(
                    child: ConfirmDialog(
                      title: 'Oslobodi Ormar',
                      message: 'Jeste li sigurni da želite osloboditi ovaj ormar?',
                      confirmButtonText: 'Oslobodi',
                      cancelButtonText: 'Otkazi',
                      confirmColor: Colors.orange,
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Delete',
                  builder: (context) => Center(
                    child: ConfirmDialog(
                      title: 'Brisanje Člana',
                      message: 'Jeste li sigurni da želite obrisati ovog člana? Ova akcija se ne može opozvati.',
                      confirmButtonText: 'Obriši',
                      cancelButtonText: 'Otkazi',
                      confirmColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'LoadingView',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (context) => const LoadingView(),
                ),
                WidgetbookUseCase(
                  name: 'With Message',
                  builder: (context) => const LoadingView(
                    message: 'Učitavanje podataka...',
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'EmptyView',
              useCases: [
                WidgetbookUseCase(
                  name: 'No Members',
                  builder: (context) => const EmptyView(
                    title: 'Nema članova',
                    subtitle: 'Počnite dodavanjem novog člana',
                    icon: Icons.group,
                    actionText: 'Dodaj člana',
                  ),
                ),
                WidgetbookUseCase(
                  name: 'No Lockers',
                  builder: (context) => const EmptyView(
                    title: 'Nema ormara',
                    subtitle: 'Sistem nema dostupnih ormara',
                    icon: Icons.lock_outline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
