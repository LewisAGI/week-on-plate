import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/cupboard.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets.dart';

class CupboardScreen extends StatefulWidget {
  const CupboardScreen({super.key, required this.session});
  final Session session;

  @override
  State<CupboardScreen> createState() => _CupboardScreenState();
}

class _CupboardScreenState extends State<CupboardScreen> {
  Map<String, dynamic>? data;
  String? error;
  bool loading = true;
  final chosen = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      data = await widget.session.api.cupboard();
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _coldStart() async {
    if (chosen.isEmpty) {
      await showMessage(context, 'Tick what you already have.');
      return;
    }
    await widget.session.api.coldStart(chosen.toList());
    await _load();
  }

  Future<void> _manualAdd() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => _AddCupboardItemDialog(session: widget.session),
    );
    if (added == true) await _load();
  }

  Future<void> _scanList() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ScanShoppingListScreen(session: widget.session),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = (data?['items'] as List? ?? []).cast<Map<String, dynamic>>();
    final empty = data?['empty'] == true;
    final staples = (data?['staples'] as List? ?? []).cast<Map<String, dynamic>>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cupboard'),
        actions: [
          IconButton(
            tooltip: 'Scan shopping list',
            onPressed: _scanList,
            icon: const Icon(Icons.document_scanner_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _manualAdd,
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? EmptyHint(text: error!)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  children: [
                    const Text(
                      'Start with what is already in the house. Add items by hand, or scan a shopping list. Untick as you use it. When you mark a meal cooked, we will ask whether to take it off.',
                      style: TextStyle(color: kMuted, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _scanList,
                      icon: const Icon(Icons.document_scanner_outlined),
                      label: const Text('Scan shopping list'),
                    ),
                    if (empty) ...[
                      const SizedBox(height: 16),
                      const Text('What is in the cupboard?', style: TextStyle(fontWeight: FontWeight.w700, color: kGreen, fontSize: 18)),
                      const SizedBox(height: 8),
                      for (final s in staples)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(s['name'] as String),
                          value: chosen.contains(s['name']),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                chosen.add(s['name'] as String);
                              } else {
                                chosen.remove(s['name']);
                              }
                            });
                          },
                        ),
                      FilledButton(onPressed: _coldStart, child: const Text('Save cupboard')),
                    ] else
                      for (final item in items)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item['name'] as String),
                          subtitle: Text(
                            item['in_stock'] == 1
                                ? qtyLabel(item['quantity'], item['unit'] as String?)
                                : 'Used up',
                          ),
                          value: item['in_stock'] == 1,
                          onChanged: (v) async {
                            await widget.session.api.patchCupboard(item['id'] as String, {'in_stock': v});
                            await _load();
                          },
                        ),
                  ],
                ),
    );
  }
}

class _AddCupboardItemDialog extends StatefulWidget {
  const _AddCupboardItemDialog({required this.session});
  final Session session;

  @override
  State<_AddCupboardItemDialog> createState() => _AddCupboardItemDialogState();
}

class _AddCupboardItemDialogState extends State<_AddCupboardItemDialog> {
  final name = TextEditingController();
  final quantity = TextEditingController();
  String unit = 'each';
  bool busy = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    quantity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final trimmed = name.text.trim();
    if (trimmed.isEmpty) {
      setState(() => error = 'Give the item a name.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.session.api.addCupboardItems([
        {
          'name': trimmed,
          'quantity': num.tryParse(quantity.text.trim()),
          'unit': unit,
        },
      ]);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add to the cupboard'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Something you already own — no receipt needed.',
            style: TextStyle(color: kMuted),
          ),
          const SizedBox(height: 12),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Item'), autofocus: true),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: quantity,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: DropdownButtonFormField<String>(
                  initialValue: unit,
                  items: const [
                    DropdownMenuItem(value: 'each', child: Text('each')),
                    DropdownMenuItem(value: 'g', child: Text('g')),
                    DropdownMenuItem(value: 'kg', child: Text('kg')),
                    DropdownMenuItem(value: 'ml', child: Text('ml')),
                    DropdownMenuItem(value: 'l', child: Text('l')),
                  ],
                  onChanged: (v) => setState(() => unit = v ?? 'each'),
                  decoration: const InputDecoration(labelText: 'Unit'),
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: busy ? null : _save, child: Text(busy ? 'Adding…' : 'Add item')),
      ],
    );
  }
}

class ScanShoppingListScreen extends StatefulWidget {
  const ScanShoppingListScreen({super.key, required this.session});
  final Session session;

  @override
  State<ScanShoppingListScreen> createState() => _ScanShoppingListScreenState();
}

class _ScanShoppingListScreenState extends State<ScanShoppingListScreen> {
  final text = TextEditingController();
  final picker = ImagePicker();
  List<Map<String, dynamic>> items = [];
  final selected = <int>{};
  bool busy = false;
  String? note;

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  void _applyItems(List<Map<String, dynamic>> parsed, {String? message}) {
    setState(() {
      items = parsed;
      selected
        ..clear()
        ..addAll(List<int>.generate(parsed.length, (i) => i));
      note = message;
    });
  }

  Future<void> _parseText() async {
    final local = parseShoppingListText(text.text);
    setState(() => busy = true);
    try {
      final data = await widget.session.api.scanCupboardList(text: text.text);
      final remote = (data['items'] as List? ?? []).cast<Map<String, dynamic>>();
      _applyItems(remote.isNotEmpty ? remote : local, message: data['message'] as String?);
    } catch (_) {
      _applyItems(
        local,
        message: local.isEmpty
            ? 'Could not reach the scanner. Type the list one item per line and try again.'
            : 'Check these before they go in the cupboard.',
      );
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _pick(ImageSource source) async {
    setState(() {
      busy = true;
      note = null;
    });
    try {
      final file = await picker.pickImage(source: source, maxWidth: 1280, imageQuality: 70);
      if (file == null) {
        if (mounted) setState(() => busy = false);
        return;
      }
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      try {
        final data = await widget.session.api.scanCupboardList(imageBase64: b64, text: text.text);
        final remote = (data['items'] as List? ?? []).cast<Map<String, dynamic>>();
        _applyItems(
          remote,
          message: data['message'] as String? ??
              (remote.isEmpty
                  ? 'Could not read that photo yet. Type or paste the list below.'
                  : null),
        );
      } catch (_) {
        final local = parseShoppingListText(text.text);
        _applyItems(
          local,
          message:
              'Photo reading needs a follow-up on this device. Type or paste the list — one item per line — and we will pick them out.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          note =
              'Camera or photos are not available here. Type or paste the shopping list instead.';
        });
      }
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _confirm() async {
    final chosen = [
      for (final i in selected)
        if (i >= 0 && i < items.length) items[i],
    ];
    if (chosen.isEmpty) {
      await showMessage(context, 'Tick at least one item to add.');
      return;
    }
    setState(() => busy = true);
    try {
      await widget.session.api.addCupboardItems(chosen);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to the cupboard.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString());
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan shopping list')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Photograph a paper list after the shop, or type what you already bought. We suggest cupboard items — nothing is saved until you confirm. This is not a checkout.',
            style: TextStyle(color: kMuted, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Take photo'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_outlined),
                  label: const Text('Choose photo'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: text,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'Or type / paste the list',
              hintText: '400g chicken breast\nMilk\n6 eggs',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy ? null : _parseText,
            child: Text(busy ? 'Reading…' : 'Read list'),
          ),
          if (note != null) ...[
            const SizedBox(height: 12),
            Text(note!, style: const TextStyle(color: kMuted, height: 1.4)),
          ],
          if (items.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Add to the cupboard', style: TextStyle(fontWeight: FontWeight.w700, color: kGreen, fontSize: 18)),
            for (var i = 0; i < items.length; i++)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(items[i]['name'] as String? ?? ''),
                subtitle: Text(qtyLabel(items[i]['quantity'], items[i]['unit'] as String?)),
                value: selected.contains(i),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      selected.add(i);
                    } else {
                      selected.remove(i);
                    }
                  });
                },
              ),
            FilledButton(onPressed: busy ? null : _confirm, child: const Text('Add selected')),
          ],
        ],
      ),
    );
  }
}
