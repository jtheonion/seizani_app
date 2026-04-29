import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:seizani_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Image Selection Button Tests', () {
    testWidgets('Gallery button exists and is tappable', (
      WidgetTester tester,
    ) async {
      // アプリを起動
      app.main();

      // アプリの完全な読み込みを待機
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // "ギャラリーから選択" ボタンを探す
      final galleryButton = find.text('ギャラリーから選択');

      // ボタンが存在することを確認
      expect(galleryButton, findsOneWidget);

      debugPrint('✅ ギャラリーから選択ボタンが見つかりました');

      // ボタンをタップ
      await tester.tap(galleryButton);
      await tester.pump(const Duration(milliseconds: 100));

      debugPrint('✅ ギャラリーから選択ボタンをタップしました');

      // 処理を待機
      await tester.pumpAndSettle(const Duration(seconds: 3));

      debugPrint('✅ 処理完了');
    });

    testWidgets('Camera button exists and is tappable', (
      WidgetTester tester,
    ) async {
      // アプリを起動
      app.main();

      // アプリの完全な読み込みを待機
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // "カメラで撮影" ボタンを探す
      final cameraButton = find.text('カメラで撮影');

      // ボタンが存在することを確認
      expect(cameraButton, findsOneWidget);

      debugPrint('✅ カメラで撮影ボタンが見つかりました');

      // ボタンをタップ
      await tester.tap(cameraButton);
      await tester.pump(const Duration(milliseconds: 100));

      debugPrint('✅ カメラで撮影ボタンをタップしました');

      // 処理を待機
      await tester.pumpAndSettle(const Duration(seconds: 3));

      debugPrint('✅ 処理完了');
    });
  });
}
