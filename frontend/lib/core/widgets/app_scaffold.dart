import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';

class AppScaffold extends StatelessWidget {
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

  Future<void> _onFabLongPress(BuildContext context) async {
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
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: navigationShell,
      bottomNavigationBar: Container(
        height: 84,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
        decoration: BoxDecoration(
          color: c.card,
          border: Border(top: BorderSide(color: c.line)),
        ),
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
              onTap: () => context.push('/spese/nuova'),
              onLongPress: () => _onFabLongPress(context),
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
    return InkWell(
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
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
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
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 56,
        height: 56,
        margin: const EdgeInsets.only(bottom: 26),
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
    );
  }
}
