import 'dart:async';
import 'dart:convert';

import 'models/search_result.dart';
import 'models/search_result_error.dart';
import 'package:http/http.dart' as http;

class GithubClient {
  GithubClient({
    http.Client? httpClient,
    this.baseUrl = 'https://api.github.com/search/repositories?q=',
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;

  Future<SearchResult> search(String term) async {
    final response = await _httpClient.get(Uri.parse('$baseUrl$term'));
    final result = json.decode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return SearchResult.fromJson(result);
    } else {
      throw SearchResultError.fromJson(result);
    }
  }

  void close() {
    _httpClient.close();
  }
}
