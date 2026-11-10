import 'package:flutter/animation.dart';

// クローム（サイドバー・垂直タブ・パスバー・ビューアの下部メニュー）の
// スライド展開/表示切替で共通に使う動きの定数。DaiDaiの検索ボックスの展開
// （260ms・easeOutCubic）に合わせてキビキビとした速さにする
const Duration kChromeSlideDuration = Duration(milliseconds: 1000);
const Curve kChromeSlideCurve = Curves.easeOutCubic;
const Curve kChromeSlideReverseCurve = Curves.easeInCubic;
