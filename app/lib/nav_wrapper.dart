import 'package:common_github_search/common_github_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'counter_bloc.dart';
import 'counter_page.dart';
import 'drawing.dart';
import 'search/search_page.dart';

class NavWrapper extends StatefulWidget {
  const NavWrapper({super.key});

  @override
  State<NavWrapper> createState() => _NavWrapperState();
}

class _NavWrapperState extends State<NavWrapper> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (_) => GithubRepository(),
      dispose: (repository) => repository.dispose(),
      child: MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.amberAccent),
        ),
        home: Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: [
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
