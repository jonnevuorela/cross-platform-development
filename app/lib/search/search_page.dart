import 'package:app/search/search_view_model.dart';
import 'package:common_github_search/common_github_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});
  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: context.read<GithubRepository>(),
      child: BlocProvider(
        create: (context) => GithubSearchBloc(
          githubRepository: context.read<GithubRepository>(),
        ),
        child: Builder(builder: (context) {
          return ChangeNotifierProvider(
            create: (context) => GithubSearchViewModel(
              bloc: context.read<GithubSearchBloc>(),
            ),
            child: Scaffold(
              appBar: AppBar(title: Text('GitHub Search tool')),
              body: Column(
              children: [_SearchBar(), _SearchBody()],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _textController = TextEditingController();
  late GithubSearchViewModel _githubSearchViewModel;

  @override
  void initState() {
    super.initState();
    _githubSearchViewModel = context.read<GithubSearchViewModel>();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _textController,
      autocorrect: false,
      onChanged: (text) {
        _githubSearchViewModel.search(
          text,
        );
      },
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        suffixIcon: GestureDetector(
          onTap: _onClearTapped,
          child: const Icon(Icons.clear),
        ),
        border: InputBorder.none,
        hintText: 'Enter a search term',
      ),
    );
  }

  void _onClearTapped(){
      _textController.text = '';
      _githubSearchViewModel.clearSearch();
  }
}

class _SearchBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GithubSearchViewModel>();
    if (vm.showEmptyPrompt) {
      return const Text('Please enter a term to begin');
    }
    if (vm.isLoading) {
      return const CircularProgressIndicator.adaptive();
    }
    if (vm.hasError) {
      return Text(vm.errorMessage);
    }
    if (vm.hasNoResults) {
      return const Text('No Results');
    }
    return Expanded(child: _SearchResults(items: vm.items));
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.items});

  final List<SearchResultItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        return _SearchResultItem(item: items[index]);
      },
    );
  }
}

class _SearchResultItem extends StatelessWidget {
  const _SearchResultItem({required this.item});

  final SearchResultItem item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Image.network(item.owner.avatarUrl),
      ),
      title: Text(item.fullName),
      onTap: () => launchUrl(Uri.parse(item.htmlUrl)),
    );
  }
}
