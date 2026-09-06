import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/activity_models.dart';
import '../../data/data_providers.dart';
import '../../data/expense_models.dart';
import '../auth/auth_providers.dart';

enum CatalogKind { properties, categories }

class CatalogPage extends ConsumerWidget {
  const CatalogPage({super.key, required this.kind});

  final CatalogKind kind;

  bool get _isProps => kind == CatalogKind.properties;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final title = _isProps ? 'Immobili' : 'Categorie';
    final items = _isProps
        ? (ref.watch(propertiesProvider).valueOrNull ?? const <CatalogProperty>[])
            .map(_Row.fromProperty)
            .toList()
        : (ref.watch(categoriesProvider).valueOrNull ?? const <CatalogCategory>[])
            .map(_Row.fromCategory)
            .toList();

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Expanded(
            child: items.isEmpty
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                    children: [
                      EmptyState(
                        message: _isProps
                            ? 'Nessun immobile. Aggiungetene uno per etichettare le spese e tenere il registro degli appartamenti.'
                            : 'Nessuna categoria.',
                        actionLabel: 'Aggiungi',
                        onAction: () => _add(context, ref),
                      ),
                    ],
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    header: _isProps
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                            child: Text(
                              'Tocca un immobile per vedere via, civico e gli altri dati.',
                              style: TextStyle(
                                color: c.ink2,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          )
                        : null,
                    itemCount: items.length,
                    onReorderItem: (from, to) => _reorder(ref, items, from, to),
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        color: c.card.withValues(alpha: 0),
                        child: child,
                      );
                    },
                    itemBuilder: (context, i) {
                      final row = items[i];
                      return Padding(
                        key: ValueKey(row.id),
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: c.card,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(color: c.line),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            onTap: () => _edit(context, ref, row),
                            contentPadding:
                                const EdgeInsets.fromLTRB(8, 4, 4, 4),
                            leading: ReorderableDragStartListener(
                              index: i,
                              child: Semantics(
                                label: 'Riordina ${row.name}',
                                child: Icon(Icons.drag_handle, color: c.ink3),
                              ),
                            ),
                            title: Text(
                              row.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: row.subtitle == null
                                ? null
                                : Text(
                                    row.subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: c.ink2,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                            trailing: _isProps
                                ? Icon(Icons.chevron_right, color: c.ink3)
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Modifica',
                                        onPressed: () =>
                                            _edit(context, ref, row),
                                        icon: Icon(
                                          Icons.edit_outlined,
                                          color: c.ink,
                                        ),
                                      ),
                                      if (!row.locked)
                                        IconButton(
                                          tooltip: 'Rimuovi',
                                          onPressed: () =>
                                              _archive(context, ref, row),
                                          icon: Icon(
                                            Icons.delete_outline,
                                            color: c.due,
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: PrimaryButton(
                label: _isProps ? 'Aggiungi immobile' : 'Aggiungi categoria',
                onPressed: () => _add(context, ref),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    if (_isProps) {
      context.push('/altro/immobili/nuovo');
      return;
    }
    final result = await _prompt(
      context,
      title: 'Nuova categoria',
      nameLabel: 'Nome',
    );
    if (result == null) return;
    final uid = ref.read(authSessionProvider).valueOrNull?.user?.uid ?? '';
    await ref.read(householdRepositoryProvider).saveCategory(
          CatalogCategory(id: '', name: result.name, order: 99),
        );
    await _log(ref, uid, 'Ha aggiunto “${result.name}”');
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, _Row row) async {
    if (_isProps) {
      context.push('/altro/immobili/${row.id}');
      return;
    }
    final result = await _prompt(
      context,
      title: 'Modifica',
      nameLabel: 'Nome',
      initialName: row.name,
    );
    if (result == null) return;
    final current = (ref.read(categoriesProvider).valueOrNull ?? const [])
        .firstWhere((c) => c.id == row.id);
    await ref
        .read(householdRepositoryProvider)
        .saveCategory(current.copyWith(name: result.name));
    final uid = ref.read(authSessionProvider).valueOrNull?.user?.uid ?? '';
    await _log(ref, uid, 'Ha rinominato “${result.name}”');
  }

  Future<void> _archive(BuildContext context, WidgetRef ref, _Row row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = ctx.colors;
        return AlertDialog(
          backgroundColor: c.card,
          title: Text('Rimuovere “${row.name}”?', style: TextStyle(color: c.ink)),
          content: Text(
            'Non si cancella del tutto: sparisce dalle nuove spese. Le voci già salvate restano.',
            style: TextStyle(color: c.ink2),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Annulla', style: TextStyle(color: c.ink2)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Rimuovi', style: TextStyle(color: c.due)),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    final repo = ref.read(householdRepositoryProvider);
    final uid = ref.read(authSessionProvider).valueOrNull?.user?.uid ?? '';
    if (_isProps) {
      await repo.archiveProperty(row.id);
    } else {
      await repo.archiveCategory(row.id);
    }
    await _log(ref, uid, 'Ha rimosso “${row.name}”');
  }

  Future<void> _reorder(
    WidgetRef ref,
    List<_Row> items,
    int from,
    int to,
  ) async {
    final ids = [for (final r in items) r.id];
    final moved = ids.removeAt(from);
    ids.insert(to.clamp(0, ids.length), moved);
    final repo = ref.read(householdRepositoryProvider);
    if (_isProps) {
      await repo.reorderProperties(ids);
    } else {
      await repo.reorderCategories(ids);
    }
  }

  Future<void> _log(WidgetRef ref, String uid, String summary) async {
    if (uid.isEmpty) return;
    await ref.read(activityRepositoryProvider).log(
          type: ActivityType.catalogChanged,
          refId: kind.name,
          byUid: uid,
          summary: summary,
        );
  }

  Future<({String name})?> _prompt(
    BuildContext context, {
    required String title,
    required String nameLabel,
    String initialName = '',
  }) async {
    final nameCtrl = TextEditingController(text: initialName);
    final c = context.colors;
    final result = await showDialog<({String name})>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: c.card,
          title: Text(title, style: TextStyle(color: c.ink)),
          content: TextField(
            controller: nameCtrl,
            autofocus: true,
            maxLength: 40,
            style: TextStyle(color: c.ink),
            decoration: InputDecoration(
              labelText: nameLabel,
              labelStyle: TextStyle(color: c.ink2),
              counterText: '',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annulla', style: TextStyle(color: c.ink2)),
            ),
            TextButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx, (name: name));
              },
              child: Text('Salva', style: TextStyle(color: c.acc)),
            ),
          ],
        );
      },
    );
    nameCtrl.dispose();
    return result;
  }
}

class _Row {
  const _Row({
    required this.id,
    required this.name,
    this.subtitle,
    this.locked = false,
  });

  factory _Row.fromProperty(CatalogProperty p) => _Row(
        id: p.id,
        name: p.name,
        subtitle: p.listSubtitle,
      );

  factory _Row.fromCategory(CatalogCategory c) => _Row(
        id: c.id,
        name: c.name,
        locked: c.isDefault,
        subtitle: c.isDefault ? 'Predefinita' : null,
      );

  final String id;
  final String name;
  final String? subtitle;
  final bool locked;
}
