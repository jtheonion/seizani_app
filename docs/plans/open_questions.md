# open_questions.md
- 最終更新日: 2026-05-05
- バージョン: 1.0

## 未決事項
- なし。

## 環境依存の確認事項
- 起動確認は利用可能な iOS Simulator または web-server で実施する。
- DexiNed モデルは Git 管理対象外のため、別環境では `dart run tool/fetch_dexined_model.dart` による取得が必要。
- PiDiNet モデルは Git 管理対象外のため、別環境では `python3 -m pip install onnx` 後に `python3 tool/export_pidinet_onnx.py` による生成が必要。
- PiDiNet は公式 LICENSE に研究目的・商用利用要連絡の文言とMIT文面が混在するため、現在の公開判断は「非商用前提」に依存する。
