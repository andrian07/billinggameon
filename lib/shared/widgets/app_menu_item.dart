import 'package:flutter/material.dart';

class AppMenuItem {
  final String title;
  final IconData icon;
  final String menuKey;

  const AppMenuItem({
    required this.title,
    required this.icon,
    required this.menuKey,
  });
}

class SidebarSection {
  final String title;
  final List<AppMenuItem> items;

  const SidebarSection({required this.title, required this.items});
}
