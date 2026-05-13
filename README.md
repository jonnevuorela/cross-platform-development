# Learning journal of Cross-platform mobile application development course

***


13.5.2026

### Platform specific code

#### Quick start

The quick start example was quite straight forward to get running. I already had the prerequisites installed and I just ran the command from fzyzcjy/flutter_rust_bridge github repository.
``` bash
cargo install flutter_rust_bridge_codegen && flutter_rust_bridge_codegen create my_app && cd my_app && flutter run
```


![](journal/media/rust_bridge_demo.png)

#### Further experiments and use cases

One use case for the native code would be to run a local ai model. Voice recognition, text to speech, image classification or just straight up llm. This is something that I want to try out too, what kind of a language model I can run on my iPhone. 

I went to huggingface to see the latest small models that would be feasible to run with phones hardware and selected the Huggingfaces SmolLM3-3B-ONNX. I selected the ONNX model, as it was the most familiar tech for me since I have built a ONNX image recognition model wrapper in go previously.

I let an AI agent loose on my project with the prompt: "Create an llm chat interface page and bloc business logic, similar to what the project already has for gitHub search." Now that I have the boilerplate code, which im already familiar with, I can focus on harnessing the ONNX runtime in rust myself. For code generation, I used GPT-5.2-Codex on OpenCode.

The refresher on rust coding was much needed. Last time I touched rust was two years ago, when I read "The Rust Programming Language" book and did some exercises. Never really used it on anything more meaningful. Now that I think about it, I haven't had a place to use it because I find Zig to be a much more intriguing take on modern systems programming. So the excuse to use rust here was fun.

I made a very simple form of runtime initialization code, but eventually passed the rust part also to the ai agent to get with it. There is really not that much of a hand written code in this new feature but I find that I got to play around with the native code integration enough. Its very similar to Tauri, which I have used for one project. 

In the Tauri app I had a frontend for making mind maps obviously made by web technologies and had the rust to do local file reads and writes to store the contents.

Back and forth few rounds with the agent enhancing the chatting experience, I got where I wanted. The model spits out utter non-sense, but it works. I included the full 3B parameter model and a heavily quantizized version of it in case the device lacks the capacity. 

![deep pondering](journal/media/deep_ponder.png)

These are not light matters and being a 3B parameter model is hard enough already.

Now to pull the project on a mac and try to build a ios version. this wasn't so straight forward. I have only ever build and sideloaded one app on iphone prior to this one and the process wasn't smooth then and it wasn't smooth now. Eventually I got the build signed and solved also static linking problems I initially had. The models were not properly included in the bundle and there was also problems statically linking all the rust code and C++ code, but I managed eventually.





***

12.5.2026

### Integration test

At this point only thing to add to the tests are integration test. We don't have as much to do on the integration tests as the actual purposeful usage of this app is quite simple. I figured that the one thing we could test on our app is the github search's http client and to call the actual API endpoint.

As we generally don't want to run the integration test as often as the other test, I included a dart_test.yaml file with integration tag to the project, so I can easily exclude the integration test and run just the widget and unit tests.

```dart
@Tags(['integration'])
library;

import 'package:common_github_search/common_github_search.dart';
import 'package:test/test.dart';

void main() {
  group('Search integration test', () {
    late GithubClient client;

    setUp(() {
      client = GithubClient();
      print('→ Starting a new search integration test');
    });

    tearDown(() => client.close());

    test('real API returns search results for "flutter"', () async {
      final results = await client.search('flutter');
      expect(results.items, isNotEmpty);
      expect(results.items.first.fullName, contains('flutter'));
    });
  });
}
```

Tests run without integration tests.

```bash
$ flutter test --exclude-tags integration
00:01 +0: /home/jonne/repos/cross-platform-development/app/test/widget_test.dart: SearchPage Search smoke test
→ Starting a new SearchPage test
00:02 +1: /home/jonne/repos/cross-platform-development/app/test/widget_test.dart: SearchPage Search type test
→ Starting a new SearchPage test
00:02 +2: /home/jonne/repos/cross-platform-development/app/test/widget_test.dart: SearchPage Clear search test
→ Starting a new SearchPage test
00:02 +3: /home/jonne/repos/cross-platform-development/app/test/widget_test.dart: SearchPage Shows loading and results correctly
→ Starting a new SearchPage test
00:02 +4: /home/jonne/repos/cross-platform-development/app/test/widget_test.dart: CounterPage Counter smoke test
→ Starting a new CounterPage test
00:02 +5: /home/jonne/repos/cross-platform-development/app/test/widget_test.dart: CounterPage Counter increment test
→ Starting a new CounterPage test
Instance of 'CounterIncrementPressed'
Transition { currentState: 0, event: Instance of 'CounterIncrementPressed', nextState: 1 }
Change { currentState: 0, nextState: 1 }
Instance of 'CounterIncrementPressed'
Transition { currentState: 1, event: Instance of 'CounterIncrementPressed', nextState: 2 }
Change { currentState: 1, nextState: 2 }
00:02 +6: /home/jonne/repos/cross-platform-development/app/test/widget_test.dart: CounterPage Counter decrement test
→ Starting a new CounterPage test
Instance of 'CounterIncrementPressed'
Transition { currentState: 0, event: Instance of 'CounterIncrementPressed', nextState: 1 }
Change { currentState: 0, nextState: 1 }
Instance of 'CounterDecrementPressed'
Transition { currentState: 1, event: Instance of 'CounterDecrementPressed', nextState: 0 }
Change { currentState: 1, nextState: 0 }
00:02 +7: /home/jonne/repos/cross-platform-development/app/test/widget_test.dart: CounterPage Counter decrement constraint test
→ Starting a new CounterPage test
Instance of 'CounterDecrementPressed'
Transition { currentState: 0, event: Instance of 'CounterDecrementPressed', nextState: 0 }
Change { currentState: 0, nextState: 0 }
00:02 +8: /home/jonne/repos/cross-platform-development/app/test/widget_test.dart: DrawingPage Drawing Page smoke test
→ Starting a new DrawingPage test
00:02 +9: /home/jonne/repos/cross-platform-development/app/test/widget_test.dart: DrawingPage adds a point to drawing
→ Starting a new DrawingPage test
00:02 +10: All tests passed!

```

run only integration tests.

```bash
$ flutter test --tags integration
00:01 +0: /home/jonne/repos/cross-platform-development/app/test/integration_test.dart: Search integration test real API returns search results for "flutter"
→ Starting a new search integration test
00:02 +1: All tests passed!
```

With this integration test in place, I would say that we have now covered the app with proper tests.

``` bash

                             |Lines       |Functions
Filename                     |Rate     Num|Rate    Num
======================================================
[lib/]
counter_bloc.dart            |83.3%     18|    -     0
counter_page.dart            | 100%     21|    -     0
drawing.dart                 |53.7%     54|    -     0
main.dart                    | 0.0%      2|    -     0
nav_wrapper.dart             | 5.0%     20|    -     0
search/search_page.dart      |96.5%     57|    -     0
search/search_view_model.dart|87.5%     16|    -     0
======================================================
                       Total:|71.8%    188|    -     0
```

I had in mind that I should create tests for the nav wrapper as well, I completely forgot. That would have increased the coverage further more. The nav wrapper would need a widget test to test that it changes the index correctly on press and loads correct pages. It needs probably some sort unit test for the page generation.

Our github search package on the other hand, doesn't have as good coverage.

``` bash
                                    |Lines      |Functions
Filename                            |Rate    Num|Rate  Num
==========================================================
[lib/]
src/github_cache.dart               | 0.0%     6|    -   0
src/github_client.dart              | 0.0%    10|    -   0
src/github_repository.dart          | 0.0%    10|    -   0
src/github_search...search_bloc.dart| 100%    14|    -   0
src/github_search_event.dart        |33.3%     6|    -   0
src/github_search_state.dart        |81.8%    11|    -   0
src/models/github_user.dart         |20.0%     5|    -   0
src/models/search_result.dart       |12.5%     8|    -   0
src/models/search_result_error.dart |33.3%     3|    -   0
src/models/search_result_item.dart  |16.7%     6|    -   0
test_utils/mock_g..._repository.dart|14.3%     7|    -   0
test_utils/test_data.dart           | 100%     8|    -   0
==========================================================
                              Total:|40.4%    94|    -   0
```



There would be room for improvement.



***

9.5.2026

### Unit tests

Bloc has its own package for testing bloc and they seem to have  it figured out too. Writing unit tests on blocs is a breeze and complex features can get robustly tested with ease.

```dart
import 'package:mocktail/mocktail.dart';

import 'package:bloc_test/bloc_test.dart';
import 'package:common_github_search/common_github_search.dart';
import 'package:test/test.dart';

void main() {
  group(GithubSearchBloc, () {
    late MockGithubRepository mockRepository;
    late GithubSearchBloc search;

    setUp(() {
      mockRepository = MockGithubRepository();
      search = GithubSearchBloc(githubRepository: mockRepository);
      print('→ Starting a new GithubSearchBloc test');
    });

    tearDown(() => search.close());

    blocTest(
      'Search bloc smoke test',
      build: () => search,
      act: (search) => search.add(const TextChanged(text: '')),
      expect: () => [isA<SearchStateInitial>()],
      wait: const Duration(milliseconds: 350),
    );

    blocTest(
      'Search bloc searching test',
      build: () {
        when(
          () => mockRepository.search('flutter'),
        ).thenAnswer((_) async => createMockSearchResult());

        return search;
      },
      act: (search) => search.add(const TextChanged(text: 'flutter')),
      expect: () => [isA<SearchStateLoading>(), isA<SearchStateSuccess>()],
      wait: const Duration(milliseconds: 350),
      verify: (_) {
        verify(() => mockRepository.search('flutter')).called(1);
      },
    );

    blocTest(
      'Search bloc error handling test',
      build: () {
        when(
          () => mockRepository.search('badterm'),
        ).thenThrow(createMockSearchError(message: 'The error'));

        return search;
      },
      act: (search) => search.add(const TextChanged(text: 'badterm')),
      expect: () => [
        isA<SearchStateLoading>(),
        predicate<SearchStateError>((state) => state.error == 'The error'),
      ],
      wait: const Duration(milliseconds: 350),
      verify: (_) => verify(() => mockRepository.search('badterm')).called(1),
    );
  });
}
```



It truely amazes me when learning a high level language it always goes into "How do I implement this, probably some specific delegate function. Oh, there is a ready made solution to this."

```dart
when(() => {
	.askedSomething()
}).thenAnswer(() => Yes());
```

That is the whole point of high level languages though. In exchange for complex mess, you get great development speed once familiar with the tooling.

To further extend the widget tests for the github search, I went and used the newly created mock repositories in the widget tests instead of real one. This allows me to actually now test the search entries being added to ui without actually calling the api in the tests. 

To verify what the test should see, I added a env var flag to the  build to enable the mock repository instead of the real one. This way I can see for my self what the tests should see.

```bash
flutter run --dart-define=USE_MOCK=true
```

![](./journal/media/mock_data_demo.gif)

I added a one new widget test for the search to validate that the app renders the search results after search.



***

8.5.2026

### Testing UI

After skimming trough the links from moodle about testing, I went straight into the project app and tried out the boiler plate tests. From there on I started to extend the existing setup for the counter app.

Nothing really works intuitively, but I found that LLMs provides working example snippets way faster and easier than trying to search ready example from stackoverflow or other ancient platform. The problems and gymnasts that you usually try to do on the Flutters widget tests, are often quite specific, so they are hard to find the old way. In comes the further most advanced search machines of LLMs.

Tests are something that always feels lame when you think about that you have to start writing them, but once in place and every test runs successfully and as intended, it makes you feel better, the development cycle is more robust now, you can trust more the machinery of your CI pipeline and what comes out from it.

```bash
$  flutter test
00:06 +0: SearchPage Search smoke test
→ Starting a new SearchPage test
00:07 +1: SearchPage Search type test
→ Starting a new SearchPage test
00:07 +2: SearchPage Clear search test
→ Starting a new SearchPage test
00:07 +3: CounterPage Counter smoke test
→ Starting a new CounterPage test
00:07 +4: CounterPage Counter increment test
→ Starting a new CounterPage test
Instance of 'CounterIncrementPressed'
Transition { currentState: 0, event: Instance of 'CounterIncrementPressed', nextState: 1 }
Change { currentState: 0, nextState: 1 }
Instance of 'CounterIncrementPressed'
Transition { currentState: 1, event: Instance of 'CounterIncrementPressed', nextState: 2 }
Change { currentState: 1, nextState: 2 }
00:07 +5: CounterPage Counter decrement test
→ Starting a new CounterPage test
Instance of 'CounterIncrementPressed'
Transition { currentState: 0, event: Instance of 'CounterIncrementPressed', nextState: 1 }
Change { currentState: 0, nextState: 1 }
Instance of 'CounterDecrementPressed'
Transition { currentState: 1, event: Instance of 'CounterDecrementPressed', nextState: 0 }
Change { currentState: 1, nextState: 0 }
00:07 +6: CounterPage Counter decrement constraint test
→ Starting a new CounterPage test
Instance of 'CounterDecrementPressed'
Transition { currentState: 0, event: Instance of 'CounterDecrementPressed', nextState: 0 }
Change { currentState: 0, nextState: 0 }
00:07 +7: DrawingPage Drawing Page smoke test
→ Starting a new DrawingPage test
00:07 +8: DrawingPage adds a point to drawing
→ Starting a new DrawingPage test
00:07 +9: All tests passed!
```

All of the widget tests of each three pages are under the same file and I think one file suffice for each field of testing in this sized project.

``` dart
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

    setUp(() {
      search = RepositoryProvider(
        create: (_) => GithubRepository(),
        child: MaterialApp(home: const SearchPage()),
      );
      print('→ Starting a new SearchPage test');
    });

    testWidgets('Search smoke test', (WidgetTester tester) async {
      await tester.pumpWidget(search);

      expect(find.text('Please enter a term to begin'), findsOne);
      expect(find.byType(TextField), findsOne);
    });

    testWidgets('Search type test', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(search);

      final textField = find.byType(TextField);

      await tester.enterText(textField, "flutter");

      // wait for debounce
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('flutter'), findsOneWidget);
    });

    testWidgets('Clear search test', (
      WidgetTester tester,
    ) async {
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
```



***

20.4.2026

### Refactoring the architecture

I started to form the architecture more towards MVVM, but keep the bloc as domain layer orchestrator. Bloc works kinda like the use cases on a pure MVVM structure. I created extra layer on the presentation by adding a view model for the displayed page, that handles all the business logic and the UI is completely freed from handling any business logic, thus enforcing the MVVM architecture.
```
          App Layer                                Domain Layer                Data Layer     
───────────────────────────────                ─────────────────────        ──────────────────
┌─────────┐       ┌───────────┐                ┌───────────────────┐           ┌───────┐      
│  Page   │       │View Model │                │  Bloc             ├──────────►│  API  │      
│         │       │           │    states      │    ┌────────┐     │           └───────┘      
│         │◄──────┼───────────┼────────────────┼─── │cache,  │     │                          
│         │       │           │                │    │repo,   │     │                          
│         │       │           │                │    │etc..   │     │                          
│         │       │           │    events      │    └────────┘     │                          
│    ─────┼───────┼───────────┼───────────────►│                   │                          
└─────────┘       └───────────┘                └───────────────────┘                          
```
***

13.4.2026

### About architecture

Reading into compass apps code the first tough is, its obviously well structured. 

[https://github.com/flutter/samples/tree/main/compass_app](https://github.com/flutter/samples/tree/main/compass_app)

The vastness of callable and returnable mock data makes the dev experience close to what the api would return. Although I didnt catch any flutter specific here, just about the same I have for example done in past for some projects but not with flutter.

The model factory with input of json seems ergonomic way to handle model creation for the views. No need to manually write the parsing ourselves. I guess this is where the frameworks shine the most. They provide tooling to ease the development, but you have to be familiar with it to know that the tools for the job already exists in the framework.

The use cases were somewhat new concept to me. I’ve seen them, but never really thought about them much. Having an orchestration layer that handles all the moving parts fits clean architecture ideology well. By containing this job in its own layer, business logic moves out of the UI and into a dedicated place.

***
7.4.2026

I finished following the state manager building and after that I moved on to implement the bloc to the project.
Bloc seems a great tool managaing the state of the application and it has solid idea behind it which resonates with me.
I read trough the introduction part of the bloc docs and followed the trough the code examples of counter and github search.
It really seems like a library I would go with when working on a flutter app.
I think this satisfies the L5 subject as we do now HTTP POST on a API with async item loading.

![](./journal/media/statemanagementdemo.gif)
***
24.3.2026

### State management and ecosystem

After a long break between the lectures, a refresher in flutter was in place.
While having the lecture on my second monitor where subject was orbiting around UI widgets, 
I spent most of my time browsing the pub.dev page to see what are the popular packages people use with the flutter.
This gave me ideas and insight on what I can implement easily by importing the library to the project instead of building it myself or leaving the feature out of the scope.
I even found few packages which I saved for future projects where I might use flutter to build it.

The UI stuff was very helpful since I feel that you cant really utilize the knowledge on plain web technologies with mobile apps too much, so it's great to see whats out there.
I feel that the only way to get around with a new frontend framework effectively is to browse the docs, which I haven't got around yet.

The insight for state management and flutters way to use the state was also very helpful. I got a better understanding on usefulness of a app state.


***

12.2.2026

Attended to the lecture today and we went trough following the Dart tutorial. The tutorial felt really basic and at first it wasnt giving anything new to me.
***

22.01.2026

### Getting the ropes

Today I just went in on the demo app and tried out what happens on the things and how to add content of my own. I found the similiarity to the Kotlin android application development and that helped. The framework seems to provide nice set of tools to make things happen but way less verbose than in the Kotlin code.
For example the simple and good looking page navigator was way easier to craft.

I also tried a new agentic AI neovim plugin tool, which allows to run agent inline from the editor by selecting the relevant context by VIM visual mode. It is kinda more lightweight than something like opencode that runs freely on context of the whole project. The zig zag drawing page that was created today was created by this way using Grok code fast 1 model.

![](./journal/media/zigzagdemo.GIF)

***

21.01.2026

### Getting to know the tool


Last time I left on after initializing the new flutter app and looked up the tools used on flutter development.

Flutter sdk seems intuitive, but the official quick start guide was weird to say at least. The instructions doesn't say a thing on anything else than installing and using VS Code, despite they having a perfectly fine CLI tool that is easy to use.
Kinda same as you would be in a market for a new car and start looking into Mercedes-Benz and the dealer tells you to go get a taxi ride as they probably drive a new Mercedes.

Delving deeper in to the ecosystem here I see handy tools in the web interface DevTools. It brings comfort in knowing that the sdk provides niceties from the web dev into play.


***

20.01.2026

### Initialization

Going into this courses completion, I'll state that I already do have some experience in cross-platform development. I've priorly used React Native for mobile app development and Tauri for desktop app development in my personal learning projects. 

After the initial lecture of the course, and looking more into the options presented on the lecture, I've drawn a conclusion about the technology I want to use on this course. 
Much like the frameworks I mentioned earlier, many other cross-platforms also tend to cater towards enforcing the usage of familiar web technologies to develope native applications and that doesn't feel like a option that would interest me right now. 
So the most interesting technology to me on the table is the one that was kinda default already on the course, Flutter.
Flutter seems most versatile tool to me since it's capabilities in making most native apps out of the options and yet still compiling also to web format. Also since I do have tried out the two second most interesting options already, I figured why not. 

