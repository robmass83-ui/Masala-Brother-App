import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/data_providers.dart';
import '../../data/task_models.dart';
import '../auth/auth_providers.dart';

Future<TaskList?> showCreateTaskListDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final c = context.colors;
  final nameCtrl = TextEditingController();
  var personal = false;
  var busy = false;

  try {
    return await showDialog<TaskList>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> submit() async {
              final error = taskListValidationError(nameCtrl.text);
              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error)),
                );
                return;
              }
              final uid = ref.read(authSessionProvider).valueOrNull?.user?.uid;
              if (uid == null) return;
              setLocal(() => busy = true);
              try {
                final saved = await ref.read(taskRepositoryProvider).saveList(
                      draft: TaskList(
                        id: '',
                        name: nameCtrl.text.trim(),
                        ownerUid: personal ? uid : null,
                      ),
                      actorUid: uid,
                    );
                if (ctx.mounted) Navigator.pop(ctx, saved);
              } catch (_) {
                setLocal(() => busy = false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Non è stato possibile creare la lista')),
                  );
                }
              }
            }

            return AlertDialog(
              backgroundColor: c.card,
              title: Text(
                'Nuova lista',
                style: TextStyle(color: c.ink, fontWeight: FontWeight.w800),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    maxLength: 80,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      color: c.ink,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Es. Campagna',
                      counterText: '',
                      hintStyle: TextStyle(color: c.ink3),
                    ),
                    onSubmitted: (_) => busy ? null : submit(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chi la vede',
                    style: TextStyle(
                      color: c.ink2,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _VisibilityChip(
                          label: 'Condivisa',
                          selected: !personal,
                          onTap: () => setLocal(() => personal = false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _VisibilityChip(
                          label: 'Solo mia',
                          selected: personal,
                          onTap: () => setLocal(() => personal = true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    personal
                        ? 'L’altra persona non vede questa lista. Se una cosa da fare crea una spesa, quella può comunque essere divisa in due.'
                        : 'La lista è visibile a entrambi.',
                    style: TextStyle(
                      color: c.ink2,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(ctx),
                  child: Text('Annulla', style: TextStyle(color: c.ink3)),
                ),
                TextButton(
                  onPressed: busy ? null : submit,
                  child: Text(
                    busy ? 'Creazione…' : 'Crea',
                    style: TextStyle(
                      color: c.acc,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    nameCtrl.dispose();
  }
}

class _VisibilityChip extends StatelessWidget {
  const _VisibilityChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.accSoft : c.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? c.accLine : c.line),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? c.acc : c.ink2,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
