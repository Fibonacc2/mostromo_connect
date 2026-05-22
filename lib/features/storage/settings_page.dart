// apps/mostromo_connect/lib/features/search/settings_page.dart
import 'package:flutter/material.dart';
// ✅ GÜNCELLENDİ:
import 'package:shared_core/data/notifiers.dart';
import 'package:common_ui/data/themes.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SettingsSection(
            title: 'Görünüm',
            children: const [ThemeSelectorTile()],
          ),
          _SettingsSection(
            title: 'Diğer',
            children: [
              ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Hakkında'),
                subtitle: Text('Uygulama bilgileri ve sürüm notları'),
                onTap: null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                  0.6,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class ThemeSelectorTile extends StatelessWidget {
  const ThemeSelectorTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: selectedTheme,
      builder: (context, currentId, _) {
        return Column(
          children: List.generate(appThemes.length, (index) {
            final appTheme = appThemes[index];
            final color = appTheme.data.colorScheme.primary;

            return ListTile(
              leading: CircleAvatar(backgroundColor: color),
              title: Text(appTheme.name),
              trailing: currentId == index
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                selectedTheme.value = index;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${appTheme.name} seçildi'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            );
          }),
        );
      },
    );
  }
}
