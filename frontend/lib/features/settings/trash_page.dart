import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/undo_snackbar.dart';
import '../../data/data_providers.dart';
import '../../data/trash_models.dart';
import '../auth/auth_providers.dart';

class TrashPage extends ConsumerWidget {
  const TrashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final items = ref.watch(trashItemsProvider);
    final user = ref.watch(authSessionProvider).valueOrNull?.user;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('Cestino')),
      body: items.isEmpty
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: const [
                EmptyState(
                  message:
                      'Niente nel cestino. Le voci eliminate restano qui 30 giorni e si possono ripristinare.',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final item = items[i];
                return Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: c.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.kindLabel,
                              style: TextStyle(
                                color: c.ink3,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                if (item.subtitle != null) item.subtitle!,
                                'eliminata ${AppDateFormat.relative(item.deletedAt)}',
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.ink2,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: user == null
                            ? null
                            : () => _restore(context, ref, item, user.uid),
                        child: Text(
                          'Ripristina',
                          style: TextStyle(
                            color: c.acc,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    TrashItem item,
    String uid,
  ) async {
    switch (item.kind) {
      case TrashKind.expense:
        await ref.read(expenseRepositoryProvider).restore(item.id, uid);
      case TrashKind.transfer:
        await ref.read(transferRepositoryProvider).restore(item.id, uid);
      case TrashKind.task:
        await ref.read(taskRepositoryProvider).restore(item.id, uid);
      case TrashKind.taskList:
        await ref.read(taskRepositoryProvider).restoreLists([item.id], uid);
    }
    if (!context.mounted) return;
    showUndoSnackBar(
      context,
      message: 'Ripristinata',
      onUndo: () {
        switch (item.kind) {
          case TrashKind.expense:
            ref.read(expenseRepositoryProvider).softDelete(item.id, uid);
          case TrashKind.transfer:
            ref.read(transferRepositoryProvider).softDelete(item.id, uid);
          case TrashKind.task:
            ref.read(taskRepositoryProvider).softDelete(item.id, uid);
          case TrashKind.taskList:
            ref.read(taskRepositoryProvider).softDeleteLists([item.id], uid);
        }
      },
    );
  }
}
