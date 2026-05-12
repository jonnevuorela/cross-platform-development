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
