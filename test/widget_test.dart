import 'package:flutter_test/flutter_test.dart';
import 'package:dolce/app.dart';

void main() {
  testWidgets('アプリが起動してタブバーが表示される', (WidgetTester tester) async {
    // DolceApp を起動
    await tester.pumpWidget(const DolceApp());
    await tester.pump();

    // タブバーが存在することを確認
    expect(find.byType(TabShell), findsOneWidget);
  });
}
