import '../../library/models/book.dart';
import 'toc_entry.dart';

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
  final List<TocEntry> toc;
  // 現在のページ内リンクと、ページ画像の縦横比（リンクのタップ判定用）
  final List<BookLink> links;
  final double? pageAspect;

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
    this.toc = const [],
    this.links = const [],
    this.pageAspect,
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
    List<TocEntry>? toc,
    List<BookLink>? links,
    double? pageAspect,
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
      toc: toc ?? this.toc,
      links: links ?? this.links,
      pageAspect: pageAspect ?? this.pageAspect,
    );
  }
}
