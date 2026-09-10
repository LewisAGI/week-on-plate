import 'package:flutter/material.dart';

import '../state/session.dart';
import '../theme.dart';
import '../widgets.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key, required this.session});
  final Session session;

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  Map<String, dynamic>? data;
  String? error;
  bool loading = true;

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
      data = await widget.session.api.shopping();
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final buy = (data?['buy'] as List? ?? []).cast<Map<String, dynamic>>();
    final have = (data?['already_have'] as List? ?? []).cast<Map<String, dynamic>>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping list'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? EmptyHint(text: error!)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Merged from this week’s plan, minus what is already in the cupboard. No supermarket prices — that is out of scope for the MVP.',
                      style: TextStyle(color: kMuted, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    const Text('Buy', style: TextStyle(fontWeight: FontWeight.w700, color: kGreen, fontSize: 18)),
                    if (buy.isEmpty) const EmptyHint(text: 'Nothing to buy. Plan a few meals first.'),
                    for (final item in buy)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item['name'] as String),
                        trailing: Text(
                          qtyLabel(item['still_needed'] ?? item['quantity'], item['unit'] as String?),
                          style: const TextStyle(color: kGreenDark, fontWeight: FontWeight.w600),
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Text('Already in the cupboard', style: TextStyle(fontWeight: FontWeight.w700, color: kGreen, fontSize: 18)),
                    if (have.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Nothing matched the cupboard yet.', style: TextStyle(color: kMuted)),
                      ),
                    for (final item in have)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item['name'] as String),
                        subtitle: const Text('Covered'),
                      ),
                  ],
                ),
    );
  }
}
