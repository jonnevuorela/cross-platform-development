import 'dart:async';

import 'github_cache.dart';
import 'github_client.dart';
import 'models/search_result.dart';

class GithubRepository {
  GithubRepository({GithubCache? cache, GithubClient? client})
    : _cache = cache ?? GithubCache(),
      _client = client ?? GithubClient();

  final GithubCache _cache;
  final GithubClient _client;

  Future<SearchResult> search(String term) async {
    final cachedResult = _cache.get(term);
    if (cachedResult != null) {
      return cachedResult;
    }
    final result = await _client.search(term);
    _cache.set(term, result);
    return result;
  }

  void dispose() {
    _cache.close();
    _client.close();
  }
}
