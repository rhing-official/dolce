import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// アプリのお知らせを画面上部のバナー（MaterialBanner）で表示する。
/// 直前のバナーは消してから出し、[duration]後に自動で消える。
/// 自動で消す処理は、このバナー自身のコントローラで閉じる（後から出た別の
/// バナーを誤って消さないため）
void showAppBanner(BuildContext context, String message,
    {Duration duration = const Duration(seconds: 4)}) {
  final messenger = ScaffoldMessenger.of(context);
  final loc = AppLocalizations.of(context)!;
  messenger.clearMaterialBanners();
  final controller = messenger.showMaterialBanner(
    MaterialBanner(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => messenger.hideCurrentMaterialBanner(),
          child: Text(loc.close),
        ),
      ],
    ),
  );
  Future.delayed(duration, controller.close);
}
