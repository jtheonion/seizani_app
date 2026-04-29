# project_checklist.md
- 最終更新日: 2026-04-30
- バージョン: 1.0

## 独立プロジェクト化チェックリスト
- [x] `<project-root>` を作成
- [x] 最新版候補の `seizani_app` をコピー
- [x] `project_starter_template_v4` の `.agent` と標準文書構成を取り込み
- [x] `seizani_app` 関連文書を canonical docs へコピー
- [x] `docs/plans/designs.md` を追加
- [x] DexiNed チェックリストを `docs/plans/seizani_app_dexined_checklist.md` として保持
- [x] `flutter pub get` を確認
- [x] `flutter test` を確認
- [x] `dart analyze` を確認
- [x] 起動確認を実施または blocker 記録
- [x] 新規 Git リポジトリとして初回コミット

## DexiNed 実装チェックリスト
# seizani_app_dexined_checklist.md
- 最終更新日: 2026-04-28

## DexiNed端末内線画変換チェックリスト
- [x] `LineArtAlgorithm.dexined` を追加
- [x] DexiNed ONNX推論サービスを追加
- [x] DexiNed後処理をテスト可能な形で実装
- [x] `DexiNed線画` プリセットを追加
- [x] `flutter_onnxruntime` 依存と `assets/models/` を追加
- [x] iOS 16.0 / static linkage を設定
- [x] Android ProGuard keep rule を追加
- [x] ONNXモデル取得スクリプトとSHA256検証を追加
- [x] ONNXモデル取得スクリプトの実行成功を確認
- [x] DexiNed後処理、JSON、プリセットのテストを追加
- [x] 星座生成系の既存テスト失敗を修正
- [x] 全体 `flutter test` 通過を確認
- [x] iOS Simulator起動確認

## DexiNed調整UI追加チェックリスト
- [x] 既存DexiNed ONNX経路を利用する方針を維持
- [x] `LineArtParameters` にDexiNed調整値を追加
- [x] DexiNed後処理へ調整値を伝播
- [x] DexiNed選択時だけ設定シートを表示
- [x] 既存シンプル版プリセットの即時処理を維持
- [x] DexiNed線画から既存星座化経路へ進める状態を維持
- [x] JSON、後処理、Widget testを追加
- [x] `dart format .` を実行
- [x] `dart analyze` を実行
- [x] `flutter test` を実行
- [x] iOS Simulatorでサンプル画像のDexiNed調整から星座化まで確認

## シンプル版星座変換方式への復帰チェックリスト
- [x] DexiNed端末内ONNX線画変換と調整UIを維持
- [x] `StarDecorationParams` / `LineArtDecorationEntity` を追加
- [x] 旧シンプル版 `LineArtStarDecorator` 相当を追加
- [x] `ProcessingRepository.decorateLineArt()` を追加
- [x] `LineArtStarDecorationUseCase` を追加
- [x] 2段階変換後の `星座に変換` をシンプル版星装飾へ差し替え
- [x] 星座変換時の調整UIを追加
- [x] 保存/共有対象を装飾済みPNGへ対応
- [x] `StarDecorationParams` / `LineArtStarDecorator` / provider-widget testを追加
- [x] `dart format .` を実行
- [x] `dart analyze` を実行
- [x] `flutter test` を実行
- [x] iOS SimulatorでDexiNed線画からシンプル版星座変換まで確認

