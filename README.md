# seizani_app

seizani_app は、写真を端末内推論で線画へ変換し、星座風の装飾画像として仕上げる Flutter アプリです。現在は DexiNed と PiDiNet の ONNX 線画変換、調整 UI、線画から星座風ビジュアルを生成する 2 段階フローを中心に開発しています。

## Features

- 写真から線画を生成する on-device ONNX inference
- DexiNed / PiDiNet ベースの線画プリセット
- 線画のしきい値、線幅、反転などの調整 UI
- 線画を星座風の点・線・装飾画像へ変換する生成フロー
- unit / widget tests と、手動検証向け integration test の配置
- モデル本体を Git 管理せず、取得・生成手順をツール化する OSS 公開方針

## Why This Project

seizani_app は早期段階の公開 Flutter アプリですが、写真加工の中でもプライバシー影響が出やすい画像処理を端末内で完結させることを重視しています。公開リポジトリでは、モデル本体を再配布せず取得・生成手順と SHA256 検証を分離し、CI、テスト、文書化、Issue triage の運用を見える形で維持します。

OSS としての主な価値は次の点です。

- Flutter で on-device ONNX inference を扱う実装例を提供する
- AI 画像処理アプリで、モデル再配布とユーザー画像の公開リスクを分けて扱う
- 線画化と星座風装飾の 2 段階フローを unit / widget tests で検証する
- Codex などの開発支援ツールを、保守、テスト、ドキュメント改善の実務に使う

## Project Layout

- `lib/`: Flutter アプリ本体
- `test/`: unit / widget tests
- `integration_test/`: 手動 / 統合検証向けテスト
- `assets/images/`: サンプル画像
- `assets/models/`: ローカル ONNX モデル置き場。モデル本体は Git 管理しません
- `tool/`: ONNX モデル取得・変換補助ツール
- `.github/workflows/`: GitHub Actions CI
- `.agent/`: project_starter_template_v4 準拠のエージェントルール
- `docs/plans/`: 要件、計画、設計、検証結果の正本
- `work/memory/`: 作業メモ、判断記録、失敗記録

## Setup

```sh
flutter pub get
```

DexiNed を使う場合は、モデルを `assets/models/` に配置します。既存の作業コピーにはモデルが残っている場合がありますが、Git 管理対象外です。再取得する場合は以下を使用します。

```sh
dart run tool/fetch_dexined_model.dart
```

取得対象は `assets/models/edge_detection_dexined_2024sep.onnx` で、SHA256 は `a50d01dc8481549c7dedb9eb3e0123b810a016520df75e4669a504609982cdd0` を期待します。

PiDiNet を使う場合は、公式 source archive と checkpoint から ONNX を生成します。

```sh
python3 tool/export_pidinet_onnx.py
```

生成対象は `assets/models/pidinet_table5_carv4_ort.onnx` です。PiDiNet の公式 LICENSE は商用利用時に追加確認が必要なため、このリポジトリではモデル本体を再配布しません。

## Verification

```sh
flutter pub get
dart analyze
flutter test
flutter devices
```

起動確認は利用可能な iOS Simulator があれば `flutter run -d <device-id>`、なければ web-server で確認します。

## Maintenance Policy

- 大きな ONNX モデル、build outputs、coverage outputs、local device settings は Git 管理しません。
- 仕様判断、検証結果、未決事項は `docs/plans/` に記録します。
- 外部モデルの license / redistribution condition は公開前に確認し、モデル本体は必要に応じて取得手順だけを提供します。
- PR / push では GitHub Actions で `flutter pub get`、`dart analyze`、`flutter test` を実行します。
- Issue では不具合の再現条件、環境、期待結果、実際の結果を分けて記録し、個人写真、EXIF 付き画像、秘密情報、モデル本体の添付は避けます。
- security tooling や maintenance resources を利用できる場合でも、対象は自分が管理・確認権限を持つこのリポジトリと正当な OSS 保守作業に限定します。

## Contributing

Contributions are welcome for bug reports, documentation fixes, tests, and narrowly scoped implementation improvements. See `CONTRIBUTING.md` for the expected workflow and public-safety rules before opening an issue or pull request.

## Documentation

このプロジェクトの文書管理は `.agent/DOCS.md` に従います。主要文書は `docs/plans/requirements.md`, `docs/plans/plans.md`, `docs/plans/designs.md`, `docs/plans/project_checklist.md`, `docs/plans/implementation_summary.md`, `docs/plans/open_questions.md` です。

## License

This project is licensed under the MIT License. See `LICENSE` for details.
