import 'dart:core';

import 'package:app/provider.dart';
import 'package:flutter/material.dart';

import 'counter.dart';
import 'drawing.dart';

void main() {
  runApp(
    Provider(
      notifier: CounterNotifier(CounterModel(username: "Gorre")),
      child: const MyApp(),
    ),
  );
}

class MainPage extends StatefulWidget {
  final String title;

  const MainPage({super.key, required this.title});

  @override
  State<MainPage> createState() => _MainPageState();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amberAccent),
      ),
      home: const MainPage(title: 'Flutter App Home Page'),
    );
  }
}

class _MainPageState extends State<MainPage> {
  int currentPageIndex = 0;

  final List<String> pageTitles = ['Home', 'Draw'];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final counterNotifier = Provider.of<CounterNotifier>(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              '${counterNotifier.value.username} has pushed the button this many times:',
            ),
            Text(
              '${counterNotifier.value.counter}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => counterNotifier.increment(),
        child: const Icon(Icons.add),
      ),
    );


  }
}
