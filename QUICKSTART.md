# QUICKSTART

## 1. 依存関係

```sh
cd seizani_app
flutter pub get
```

## 2. DexiNed モデル

`assets/models/*.onnx` は Git 管理対象外です。作業コピーにモデルがない場合は次を実行します。

```sh
dart run tool/fetch_dexined_model.dart
```

期待する主モデルは `assets/models/edge_detection_dexined_2024sep.onnx` です。

## 3. 検証

```sh
flutter test
dart analyze
flutter devices
```

利用可能なデバイスがある場合:

```sh
flutter run -d <device-id>
```

Web 起動確認を使う場合:

```sh
flutter run -d web-server
```

## 4. 文書運用

- ルール: `AGENTS.md`, `.agent/DOCS.md`, `.agent/PLANS.md`
- 要件: `docs/plans/requirements.md`
- 計画: `docs/plans/plans.md`
- 設計: `docs/plans/designs.md`
- 検証記録: `docs/plans/implementation_summary.md`
- 未決事項: `docs/plans/open_questions.md`
