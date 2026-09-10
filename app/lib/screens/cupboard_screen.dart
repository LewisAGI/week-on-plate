import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final items = (data?['items'] as List? ?? []).cast<Map<String, dynamic>>();
    final empty = data?['empty'] == true;
    final staples = (data?['staples'] as List? ?? []).cast<Map<String, dynamic>>();

    return Scaffold(
      appBar: AppBar(title: const Text('Cupboard')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? EmptyHint(text: error!)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Start with what is already in the house. Untick as you use it. When you mark a meal cooked, we will ask whether to take it off.',
                      style: TextStyle(color: kMuted, height: 1.4),
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
