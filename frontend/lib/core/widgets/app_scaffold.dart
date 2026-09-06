import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/data_providers.dart';
import '../../features/auth/auth_providers.dart';
import '../../features/tasks/task_list_dialog.dart';
import '../connectivity/connectivity_provider.dart';
import '../notifications/task_notifications.dart';
import '../prefs/settings_providers.dart';
import '../theme/app_colors.dart';
import 'offline_banner.dart';

class AppScaffold extends ConsumerWidget {
  const AppScaffold({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  int get _index => navigationShell.currentIndex;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  Future<void> _onFabTap(BuildContext context, WidgetRef ref) async {
    if (_index != 2) {
      context.push('/spese/nuova');
      return;
    }
    final c = context.colors;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Cosa vuoi aggiungere?',
                  style: TextStyle(
                    color: c.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: Text(
                    'Nuova lista',
                    style: TextStyle(
                      color: c.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Es. Campagna, poi le cose da fare dentro',
                    style: TextStyle(color: c.ink2, fontWeight: FontWeight.w600),
                  ),
                  onTap: () => Navigator.pop(ctx, 'list'),
                ),
                ListTile(
                  title: Text(
                    'Cosa da fare',
                    style: TextStyle(
                      color: c.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Senza lista, una sola voce',
                    style: TextStyle(color: c.ink2, fontWeight: FontWeight.w600),
                  ),
                  onTap: () => Navigator.pop(ctx, 'task'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!context.mounted || choice == null) return;
    if (choice == 'task') {
      context.push('/dafare/nuova');
      return;
    }
    final list = await showCreateTaskListDialog(context, ref);
    if (!context.mounted || list == null) return;
    context.push('/dafare/nuova', extra: {'listId': list.id});
  }

  Future<void> _onFabLongPress(BuildContext context, WidgetRef ref) async {
    final c = context.colors;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    'Nuova spesa',
                    style: TextStyle(
                      color: c.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/spese/nuova');
                  },
                ),
                ListTile(
                  title: Text(
                    'Nuova cosa da fare',
                    style: TextStyle(
                      color: c.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/dafare/nuova');
                  },
                ),
                ListTile(
                  title: Text(
                    'Nuova lista',
                    style: TextStyle(
                      color: c.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    showCreateTaskListDialog(context, ref);
                  },
                ),
                ListTile(
                  title: Text(
                    'Registra bonifico',
                    style: TextStyle(
                      color: c.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/bonifici/nuovo');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final uid = ref.watch(authSessionProvider).valueOrNull?.user?.uid;
    final tasks = ref.watch(visibleTasksProvider);
    final hour = ref.watch(reminderHourProvider);
    final online = ref.watch(isOnlineProvider).valueOrNull ?? true;
    if (uid != null) {
      unawaited(
        Future<void>.microtask(() {
          TaskNotifications.sync(
            tasks: tasks,
            currentUid: uid,
            hour: hour,
          );
        }),
      );
    }
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return BackButtonListener(
      onBackButtonPressed: () async {
        final go = GoRouter.of(context);
        if (go.canPop()) {
          go.pop();
          return true;
        }
        return false;
      },
      child: Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          if (!online) const OfflineBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: Material(
        color: c.card,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.line)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomInset),
            child: SizedBox(
              height: 56,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavItem(
                    label: 'Riepilogo',
                    selected: _index == 0,
                    icon: Icons.home_outlined,
                    onTap: () => _onTap(0),
                  ),
                  _NavItem(
                    label: 'Spese',
                    selected: _index == 1,
                    icon: Icons.list_alt_outlined,
                    onTap: () => _onTap(1),
                  ),
                  _FabButton(
                    onTap: () => _onFabTap(context, ref),
                    onLongPress: () => _onFabLongPress(context, ref),
                  ),
                  _NavItem(
                    label: 'Da fare',
                    selected: _index == 2,
                    icon: Icons.check_box_outlined,
                    onTap: () => _onTap(2),
                  ),
                  _NavItem(
                    label: 'Altro',
                    selected: _index == 3,
                    icon: Icons.more_horiz,
                    onTap: () => _onTap(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = selected ? c.acc : c.ink3;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 64,
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 3),
              ExcludeSemantics(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FabButton extends StatelessWidget {
  const _FabButton({required this.onTap, required this.onLongPress});

  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'Nuova spesa. Tieni premuto per altre azioni',
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: c.acc,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: c.accShadow,
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(Icons.add, color: c.onAcc, size: 28),
        ),
      ),
    );
  }
}
