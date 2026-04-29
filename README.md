# seizani_app

写真から線画を生成し、星座風の装飾画像へ変換する Flutter アプリです。現在の主な実装は DexiNed ONNX による端末内線画変換、調整 UI、シンプル版の星装飾変換です。

## Project Layout

- `lib/`: Flutter アプリ本体
- `test/`: unit/widget tests
- `integration_test/`: 手動/統合検証向けテスト
- `assets/images/`: サンプル画像
- `assets/models/`: ローカル ONNX モデル置き場。モデル本体は Git 管理しません
- `tool/`: DexiNed モデル取得・変換補助ツール
- `.agent/`: project_starter_template_v4 準拠のエージェントルール
- `docs/plans/`: 要件、計画、設計、検証結果の正本
- `work/memory/`: 作業メモ、判断記録、失敗記録

## Setup

```sh
flutter pub get
```

DexiNed を使う場合は、モデルを `assets/models/` に配置します。既存の作業コピーにはモデルが残っていますが、Git 管理対象外です。再取得する場合は以下を使用します。

```sh
dart run tool/fetch_dexined_model.dart
```

取得対象は `assets/models/edge_detection_dexined_2024sep.onnx` で、SHA256 は `a50d01dc8481549c7dedb9eb3e0123b810a016520df75e4669a504609982cdd0` を期待します。

## Verification

```sh
flutter pub get
flutter test
dart analyze
flutter devices
```

起動確認は利用可能な iOS Simulator があれば `flutter run -d <device-id>`、なければ web-server で確認します。

## Documentation

このプロジェクトの文書管理は `.agent/DOCS.md` に従います。主要文書は `docs/plans/requirements.md`, `docs/plans/plans.md`, `docs/plans/designs.md`, `docs/plans/project_checklist.md`, `docs/plans/implementation_summary.md`, `docs/plans/open_questions.md` です。
