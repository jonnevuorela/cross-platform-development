import 'package:common_github_search/common_github_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:llm_chat/llm_chat.dart';
import 'package:google_fonts/google_fonts.dart';

import 'chat/chat_page.dart';
import 'chat/rust_chat_repository.dart';
import 'counter_bloc.dart';
import 'counter_page.dart';
import 'drawing.dart';
import 'search/search_page.dart';
import 'ui/app_messenger.dart';

class NavWrapper extends StatefulWidget {
  const NavWrapper({super.key, this.useMock = false});

  final bool useMock;

  @override
  State<NavWrapper> createState() => _NavWrapperState();
}

class _NavWrapperState extends State<NavWrapper> {
  int _currentIndex = 0;

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final seed = isDark ? const Color(0xFF8B5CF6) : const Color(0xFF4F46E5);
    final background = isDark ? const Color(0xFF0B0B10) : const Color(0xFFF7F7FB);
    final surface = isDark ? const Color(0xFF141423) : const Color(0xFFFFFFFF);
    final secondary = isDark ? const Color(0xFF22D3EE) : const Color(0xFF06B6D4);
    final outline = isDark ? const Color(0xFF26263B) : const Color(0xFFE5E7F3);
    final onSurface = isDark ? const Color(0xFFE9E9FF) : const Color(0xFF0F1024);
    final onBackground = isDark ? const Color(0xFFE9E9FF) : const Color(0xFF0F1024);
    final tertiary = isDark ? const Color(0xFFF472B6) : const Color(0xFFEC4899);

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
        primary: seed,
        secondary: secondary,
        tertiary: tertiary,
        background: background,
        surface: surface,
        onSurface: onSurface,
        onBackground: onBackground,
      ),
      textTheme: GoogleFonts.spaceGroteskTextTheme().apply(
        bodyColor: onSurface,
        displayColor: onSurface,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
      ),
      scaffoldBackgroundColor: background,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(
          color: isDark ? const Color(0xFF9B9BC6) : const Color(0xFF6D6EA3),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: seed, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: seed,
        unselectedItemColor:
            isDark ? const Color(0xFFA6A6D9) : const Color(0xFF6A6D9C),
        backgroundColor: surface,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surface,
        contentTextStyle: TextStyle(color: onSurface),
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: outline.withOpacity(0.8)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<GithubRepository>(
          create: (_) => widget.useMock
              ? MockGithubRepository(withMockData: true)
              : GithubRepository(),
          dispose: (repository) => repository.dispose(),
        ),
        RepositoryProvider<ChatRepository>(create: (_) => RustChatRepository()),
      ],
      child: MaterialApp(
        scaffoldMessengerKey: appMessengerKey,
        themeMode: ThemeMode.system,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        home: Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: [
              const ChatPage(),
              BlocProvider(create: (_) => CounterBloc(), child: CounterPage()),
              const SearchPage(),
              const DrawingPage(title: 'Drawing'),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_outline),
                label: 'Chat',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.add_circle),
                label: 'Counter',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: 'Search',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.brush),
                label: 'Drawing',
              ),

            ],
          ),
        ),
      ),
    );
  }
}
