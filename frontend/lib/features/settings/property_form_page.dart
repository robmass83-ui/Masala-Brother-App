import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/keyboard_dismiss.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/activity_models.dart';
import '../../data/data_providers.dart';
import '../../data/expense_models.dart';
import '../auth/auth_providers.dart';

class PropertyFormPage extends ConsumerStatefulWidget {
  const PropertyFormPage({super.key, this.id});

  final String? id;

  @override
  ConsumerState<PropertyFormPage> createState() => _PropertyFormPageState();
}

class _PropertyFormPageState extends ConsumerState<PropertyFormPage> {
  final _nameCtrl = TextEditingController();
  final _shortCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _houseNumberCtrl = TextEditingController();
  final _internoCtrl = TextEditingController();
  final _scalaCtrl = TextEditingController();
  final _floorCtrl = TextEditingController();
  final _postalCodeCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _loaded = false;
  bool _missing = false;
  bool _busy = false;
  CatalogProperty? _existing;

  bool get _isEdit => widget.id != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _shortCtrl.dispose();
    _streetCtrl.dispose();
    _houseNumberCtrl.dispose();
    _internoCtrl.dispose();
    _scalaCtrl.dispose();
    _floorCtrl.dispose();
    _postalCodeCtrl.dispose();
    _cityCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _fillFrom(CatalogProperty p) {
    _existing = p;
    _nameCtrl.text = p.name;
    _shortCtrl.text = p.shortName == p.name ? '' : p.shortName;
    _streetCtrl.text = p.street;
    _houseNumberCtrl.text = p.houseNumber;
    _internoCtrl.text = p.interno;
    _scalaCtrl.text = p.scala;
    _floorCtrl.text = p.floor;
    _postalCodeCtrl.text = p.postalCode;
    _cityCtrl.text = p.city;
    _notesCtrl.text = p.notes;
  }

  CatalogProperty _draft() {
    final name = _nameCtrl.text.trim();
    return CatalogProperty(
      id: _existing?.id ?? '',
      name: name,
      shortName: _shortCtrl.text.trim(),
      order: _existing?.order ?? 99,
      street: _streetCtrl.text,
      houseNumber: _houseNumberCtrl.text,
      interno: _internoCtrl.text,
      scala: _scalaCtrl.text,
      floor: _floorCtrl.text,
      postalCode: _postalCodeCtrl.text,
      city: _cityCtrl.text,
      notes: _notesCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_isEdit && !_loaded && !_missing) {
      final async = ref.watch(propertiesProvider);
      final props = async.valueOrNull;
      if (props != null) {
        final match = props.where((p) => p.id == widget.id);
        if (match.isEmpty) {
          _missing = true;
        } else {
          _fillFrom(match.first);
          _loaded = true;
        }
      } else if (async.hasError) {
        _missing = true;
      }
    }

    if (_isEdit && _missing) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(title: const Text('Immobile')),
        body: const Center(child: Text('Immobile non trovato')),
      );
    }

    if (_isEdit && !_loaded) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(title: const Text('Immobile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(_isEdit ? 'Dettaglio immobile' : 'Nuovo immobile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_isEdit)
            TextButton(
              onPressed: _busy ? null : _archive,
              child: Text('Rimuovi', style: TextStyle(color: c.due)),
            )
          else
            TextButton(
              onPressed: () => context.pop(),
              child: Text('Annulla', style: TextStyle(color: c.ink3)),
            ),
        ],
      ),
      bottomNavigationBar: Material(
        color: c.bg,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            12 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          child: PrimaryButton(
            label: _busy ? 'Salvataggio…' : 'Salva',
            onPressed: _busy ? null : _save,
          ),
        ),
      ),
      body: KeyboardDismiss(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Nelle spese si vede l’etichetta, per esempio Via Forlanini. '
              'Qui sotto tieni via, civico e gli altri dati: è il registro degli appartamenti.',
              style: TextStyle(
                color: c.ink2,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                children: [
                  _Field(
                    controller: _nameCtrl,
                    label: 'Etichetta',
                    hint: 'Via Forlanini',
                    maxLength: 40,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _shortCtrl,
                    label: 'Nome breve (chip)',
                    hint: 'Forlanini',
                    maxLength: 20,
                    textCapitalization: TextCapitalization.words,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Indirizzo',
              style: TextStyle(color: c.ink, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            AppCard(
              child: Column(
                children: [
                  _Field(
                    controller: _streetCtrl,
                    label: 'Via',
                    hint: 'Via Forlanini',
                    maxLength: 60,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _houseNumberCtrl,
                    label: 'Numero civico',
                    hint: '9',
                    maxLength: 12,
                  ),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _internoCtrl,
                    label: 'Interno',
                    maxLength: 12,
                  ),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _scalaCtrl,
                    label: 'Scala',
                    maxLength: 12,
                  ),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _floorCtrl,
                    label: 'Piano',
                    maxLength: 12,
                  ),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _postalCodeCtrl,
                    label: 'CAP',
                    hint: '07100',
                    maxLength: 5,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _cityCtrl,
                    label: 'Città',
                    hint: 'Sassari',
                    maxLength: 40,
                    textCapitalization: TextCapitalization.words,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Note',
              style: TextStyle(color: c.ink, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            AppCard(
              child: _Field(
                controller: _notesCtrl,
                label: 'Annotazioni',
                hint: 'Box, cantina, riferimenti catastali…',
                maxLength: 240,
                maxLines: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Metti un’etichetta, per esempio Via Forlanini')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(householdRepositoryProvider);
      await repo.saveProperty(_draft());
      final uid = ref.read(authSessionProvider).valueOrNull?.user?.uid ?? '';
      await _log(
        uid,
        _isEdit ? 'Ha aggiornato “$name”' : 'Ha aggiunto “$name”',
      );
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archive() async {
    final current = _existing;
    if (current == null) return;
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: c.card,
          title: Text(
            'Rimuovere “${current.name}”?',
            style: TextStyle(color: c.ink),
          ),
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
    setState(() => _busy = true);
    try {
      await ref.read(householdRepositoryProvider).archiveProperty(current.id);
      final uid = ref.read(authSessionProvider).valueOrNull?.user?.uid ?? '';
      await _log(uid, 'Ha rimosso “${current.name}”');
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _log(String uid, String summary) async {
    if (uid.isEmpty) return;
    await ref.read(activityRepositoryProvider).log(
          type: ActivityType.catalogChanged,
          refId: 'properties',
          byUid: uid,
          summary: summary,
        );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLength,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int? maxLength;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      style: TextStyle(color: c.ink, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: c.ink2),
        hintStyle: TextStyle(color: c.ink3),
        border: InputBorder.none,
        counterText: '',
      ),
    );
  }
}
