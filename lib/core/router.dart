import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/bookmarks/library_screen.dart';
import '../features/browse/browse_screen.dart';
import '../features/reader/reader_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/surah_list/surah_list_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const SurahListScreen(),
    ),
    GoRoute(
      path: '/surah/:number',
      name: 'reader',
      builder: (context, state) {
        final number = int.parse(state.pathParameters['number']!);
        final ayah = int.tryParse(state.uri.queryParameters['ayah'] ?? '');
        return ReaderScreen(surahNumber: number, initialAyah: ayah);
      },
    ),
    GoRoute(
      path: '/search',
      name: 'search',
      builder: (context, state) => const SearchScreen(),
    ),
    GoRoute(
      path: '/browse',
      name: 'browse',
      builder: (context, state) => const BrowseScreen(),
    ),
    GoRoute(
      path: '/library',
      name: 'library',
      builder: (context, state) => const LibraryScreen(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Not found')),
    body: Center(child: Text(state.error?.toString() ?? 'Page not found')),
  ),
);
