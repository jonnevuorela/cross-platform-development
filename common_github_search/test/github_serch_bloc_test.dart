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
