import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/music.dart';
import 'dio_provider.dart';
import '../../data/adapters/search_adapter.dart';

class MusicSearchState {
  final List<Music> searchResults;
  final bool isLoading;
  final String? error;
  final String searchQuery;

  const MusicSearchState({
    this.searchResults = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
  });

  MusicSearchState copyWith({
    List<Music>? searchResults,
    bool? isLoading,
    String? error,
    String? searchQuery,
  }) {
    return MusicSearchState(
      searchResults: searchResults ?? this.searchResults,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class MusicSearchNotifier extends StateNotifier<MusicSearchState> {
  final Ref ref;

  MusicSearchNotifier(this.ref) : super(const MusicSearchState());

  Future<void> searchMusic(String query) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(searchResults: [], searchQuery: '', error: null);
      return;
    }

    final apiService = ref.read(apiServiceProvider);
    if (apiService == null) return;

    try {
      state = state.copyWith(isLoading: true, searchQuery: query, error: null);

      final results = await apiService.searchMusic(query);
      final musicList = SearchAdapter.parse(results);

      state = state.copyWith(
        searchResults: musicList,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        searchResults: [],
      );
    }
  }

  void clearSearch() {
    state = state.copyWith(searchResults: [], searchQuery: '', error: null);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final musicSearchProvider =
    StateNotifierProvider<MusicSearchNotifier, MusicSearchState>((ref) {
      return MusicSearchNotifier(ref);
    });
