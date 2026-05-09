import 'package:common_github_search/common_github_search.dart';
import 'package:mocktail/mocktail.dart';

class MockGithubRepository extends Mock implements GithubRepository {
  // Overload to provide testing data with repository.
  MockGithubRepository({bool withMockData = false}) {
    if (withMockData) {
      when(
        () => search('flutter'),
      ).thenAnswer((_) async => createMockSearchResult(itemCount: 8));

      when(
        () => search(any()),
      ).thenAnswer((_) async => createMockSearchResult(itemCount: 3));
    }
  }
}

