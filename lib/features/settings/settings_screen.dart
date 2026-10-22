import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/preferences.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final quranSize = ref.watch(quranFontSizeProvider);
    final tafsirSize = ref.watch(tafsirFontSizeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (s) {
              ref.read(themeModeProvider.notifier).setMode(s.first);
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Defaults to your device theme the first time you open the app.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          Text('Quran text size', style: Theme.of(context).textTheme.titleMedium),
          Slider(
            value: quranSize,
            min: 18,
            max: 48,
            divisions: 15,
            label: quranSize.round().toString(),
            onChanged: (v) =>
                ref.read(quranFontSizeProvider.notifier).setSize(v),
          ),
          const SizedBox(height: 8),
          Text('Tafsir text size', style: Theme.of(context).textTheme.titleMedium),
          Slider(
            value: tafsirSize,
            min: 14,
            max: 36,
            divisions: 11,
            label: tafsirSize.round().toString(),
            onChanged: (v) =>
                ref.read(tafsirFontSizeProvider.notifier).setSize(v),
          ),
          const SizedBox(height: 24),
          Text('About', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Quran & Tafsir',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'A simple offline Quran reader with tafsir, built for personal use. '
            'Everything runs on your device — no account and no internet required.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Version 1.0.0',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
