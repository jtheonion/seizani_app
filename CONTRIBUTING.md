# Contributing

seizani_app は、写真を端末内で線画化し、星座風画像へ変換する Flutter アプリです。バグ報告、ドキュメント修正、テスト追加、限定的な実装改善を歓迎します。

## Before Opening An Issue

- 既存 issue と README / QUICKSTART を確認してください。
- 不具合の場合は、再現手順、期待結果、実際の結果、Flutter / Dart / OS / device 情報を書いてください。
- 個人写真、顔が識別できる画像、EXIF 付き画像、秘密情報、API key、GitHub token、モデル本体は添付しないでください。
- 画像が必要な場合は、権利と公開可否を確認済みの最小サンプル、または合成画像を使ってください。

## Pull Request Workflow

1. 変更範囲を小さく保ち、目的を PR 説明に書いてください。
2. モデル本体、build output、coverage output、local device settings を追加しないでください。
3. 可能な範囲で次の検証を実行してください。

```sh
flutter pub get
dart analyze
flutter test
git diff --check
```

4. 仕様判断、検証結果、未決事項を変更した場合は、`docs/plans/` の対応文書も更新してください。

## Security And Privacy

- 詳細な報告方針と public issue に載せない情報は `SECURITY.md` を確認してください。
- 脆弱性や悪用手順を公開 issue に詳細掲載しないでください。まず、最小限の説明で maintainer に連絡する issue を作成してください。
- 外部モデルの license / redistribution condition が不明な場合、モデル本体は追加せず、取得・生成手順と確認待ち事項だけを記録してください。
