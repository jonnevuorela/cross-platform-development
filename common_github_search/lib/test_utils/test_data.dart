import 'package:common_github_search/common_github_search.dart';

SearchResult createMockSearchResult({int itemCount = 3}) {
  return SearchResult(
    items: List.generate(
      itemCount,
      (index) => SearchResultItem(
        fullName: 'flutter/flutter-$index',
        htmlUrl: 'https://github.com/flutter/flutter-$index',
        owner: const GithubUser(
          login: 'flutter',
          avatarUrl: 'https://avatars.githubusercontent.com/u/14101776?v=4',
        ),
      ),
    ),
  );
}

SearchResultError createMockSearchError({String message = 'The error'}){
    return SearchResultError(message: message);
}
