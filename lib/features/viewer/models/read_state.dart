import '../../library/models/book.dart';

class ReadState {
  final String title;
  final String filePath;
  final BookFormat format;
  final bool isLoading;
  final bool showUI;
  final int currentPage;
  final int totalPages;
  final String? errorMessage;
  final bool autoPlay;

  ReadState({
    required this.title,
    required this.filePath,
    required this.format,
    this.isLoading = false,
    this.showUI = false,
    this.currentPage = 0,
    this.totalPages = 0,
    this.errorMessage,
    this.autoPlay = false,
  });

  ReadState copyWith({
    String? title,
    String? filePath,
    BookFormat? format,
    bool? isLoading,
    bool? showUI,
    int? currentPage,
    int? totalPages,
    String? errorMessage,
    bool? autoPlay,
  }) {
    return ReadState(
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      format: format ?? this.format,
      isLoading: isLoading ?? this.isLoading,
      showUI: showUI ?? this.showUI,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      errorMessage: errorMessage ?? this.errorMessage,
      autoPlay: autoPlay ?? this.autoPlay,
    );
  }
}
