import 'dart:async';

import 'package:common_github_search/common_github_search.dart';
import 'package:flutter/material.dart';

class GithubSearchViewModel extends ChangeNotifier {
  final GithubSearchBloc _bloc;
  late StreamSubscription _sub;

  GithubSearchViewModel({required GithubSearchBloc bloc}) : _bloc = bloc {
    _sub = _bloc.stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  bool get isLoading => _bloc.state is SearchStateLoading;
  bool get showEmptyPrompt => _bloc.state is SearchStateInitial;
  bool get hasError => _bloc.state is SearchStateError;

  String get errorMessage =>
      hasError ? (_bloc.state as SearchStateError).error : '';

  List<SearchResultItem> get items => _bloc.state is SearchStateSuccess
      ? (_bloc.state as SearchStateSuccess).items
      : [];

  bool get hasNoResults =>
      _bloc.state is SearchStateSuccess &&
      (_bloc.state as SearchStateSuccess).items.isEmpty;

  void search(String term) => _bloc.add(TextChanged(text: term));
  void clearSearch() => _bloc.add(const TextChanged(text: ''));
}
