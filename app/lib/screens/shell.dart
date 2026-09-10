import 'package:flutter/material.dart';

import '../state/session.dart';
import 'cupboard_screen.dart';
import 'more_screen.dart';
import 'recipes_screen.dart';
import 'shopping_screen.dart';
import 'week_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.session});
  final Session session;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final pages = [
      WeekScreen(session: session),
      RecipesScreen(session: session),
      ShoppingScreen(session: session),
      CupboardScreen(session: session),
      MoreScreen(session: session),
    ];
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_view_week_outlined), label: 'Week'),
          NavigationDestination(icon: Icon(Icons.restaurant_outlined), label: 'Recipes'),
          NavigationDestination(icon: Icon(Icons.shopping_basket_outlined), label: 'Shop'),
          NavigationDestination(icon: Icon(Icons.kitchen_outlined), label: 'Cupboard'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}
