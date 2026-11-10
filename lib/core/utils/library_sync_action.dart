import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/library/providers/library_provider.dart';
import '../widgets/app_banner.dart';

/// 全本棚を再スキャンして一覧を更新し、結果をバナーで知らせる。
/// F5・パスバーの更新ボタン・モバイルのナビから共通で使う。
/// 同期中に再度呼ばれても、`syncAll`の排他により二重には走らない
Future<void> refreshLibrary(BuildContext context, WidgetRef ref) async {
  debugPrint('[Sync] 更新が要求されました');
  final result = await ref.read(libraryProvider.notifier).syncAll();
  if (!context.mounted) return;
  showAppBanner(
      context,
      result.added == 0 && result.updated == 0 && result.removed == 0
          ? '変更はありませんでした'
          : '更新しました（追加${result.added}件 / 更新${result.updated}件 / 削除${result.removed}件）',
      duration: const Duration(seconds: 3));
}
