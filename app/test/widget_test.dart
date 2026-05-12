import 'package:app/counter_bloc.dart';
import 'package:app/counter_page.dart';
import 'package:app/drawing.dart';
import 'package:app/search/search_page.dart';
import 'package:common_github_search/common_github_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchPage', () {
    late Widget search;
    late MockGithubRepository mockRepo;

    setUp(() {
      mockRepo = MockGithubRepository(withMockData: true);
      search = RepositoryProvider<GithubRepository>(
        create: (_) => mockRepo,
        child: MaterialApp(home: const SearchPage()),
      );

      print('→ Starting a new SearchPage test');
    });

    testWidgets('Search smoke test', (WidgetTester tester) async {
      await tester.pumpWidget(search);

      expect(find.text('Please enter a term to begin'), findsOne);
      expect(find.byType(TextField), findsOne);
    });

    testWidgets('Search type test', (WidgetTester tester) async {
      await tester.pumpWidget(search);

      final textField = find.byType(TextField);

      await tester.enterText(textField, "flutter");

      // wait for debounce
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('flutter'), findsOneWidget);
    });

    testWidgets('Clear search test', (WidgetTester tester) async {
      await tester.pumpWidget(search);

      final textField = find.byType(TextField);

      await tester.enterText(textField, "flutter");

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.clear));

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text(''), findsOneWidget);
    });

    testWidgets('Shows loading and results correctly', (tester) async {
      await tester.pumpWidget(search);

      await tester.enterText(find.byType(TextField), 'flutter');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.byType(ListTile), findsAtLeast(1));
      expect(find.text('flutter/flutter-0'), findsOneWidget);
    });
  });

  group('CounterPage', () {
    late Widget counter;

    setUp(() {
      counter = BlocProvider(
        create: (_) => CounterBloc(),
        child: MaterialApp(home: CounterPage()),
      );
      print('→ Starting a new CounterPage test');
    });

    testWidgets('Counter smoke test', (WidgetTester tester) async {
      await tester.pumpWidget(counter);

      expect(find.text('0'), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('Counter increment test', (WidgetTester tester) async {
      await tester.pumpWidget(counter);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(find.text('0'), findsNothing);
      expect(find.text('1'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(find.text('0'), findsNothing);
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('Counter decrement test', (WidgetTester tester) async {
      await tester.pumpWidget(counter);

      expect(find.text('0'), findsOneWidget);
      expect(find.text('1'), findsNothing);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(find.text('0'), findsNothing);
      expect(find.text('1'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();

      expect(find.text('1'), findsNothing);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('Counter decrement constraint test', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(counter);

      expect(find.text('0'), findsOneWidget);
      expect(find.text('1'), findsNothing);

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();

      expect(find.text('1'), findsNothing);
      expect(find.text('-1'), findsNothing);
      expect(find.text('0'), findsOneWidget);
    });
  });

  group('DrawingPage', () {
    late Widget drawing;

    setUp(() {
      drawing = MaterialApp(home: const DrawingPage(title: 'Drawing'));
      print('→ Starting a new DrawingPage test');
    });

    testWidgets('Drawing Page smoke test', (WidgetTester tester) async {
      await tester.pumpWidget(drawing);

      final state = tester.state<DrawingPageState>(find.byType(DrawingPage));

      expect(find.byIcon(Icons.brush), findsOneWidget);
      expect(state.points.length, 0);
    });

    testWidgets('adds a point to drawing', (WidgetTester tester) async {
      await tester.pumpWidget(drawing);

      final state = tester.state<DrawingPageState>(find.byType(DrawingPage));

      await tester.tap(find.byIcon(Icons.brush));
      await tester.pump();

      expect(state.points.length, 1);
    });
  });
}
