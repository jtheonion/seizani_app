# implementation_summary.md
- 最終更新日: 2026-05-05
- バージョン: 1.0

## 2026-04-30 seizani_app 独立プロジェクト化

### 実施内容
- `<source-worktree>/seizani_app` を `<project-root>` にコピーした。
- `project_starter_template_v4` の `AGENTS.md`, `.agent/`, `docs/`, `work/` を取り込んだ。
- 既存の `seizani_app` 関連文書を `docs/plans/` に統合した。
- `README.md` と `QUICKSTART.md` を独立プロジェクト向けに更新した。
- DexiNed ONNX モデルは作業コピーに残し、Git 管理対象外とする方針を明記した。
- `<project-root>`独立プロジェクトディレクトリを新規 Git リポジトリとして初期化した。

### 検証結果
- `flutter pub get`: 成功。依存関係を解決済み。更新可能パッケージの通知のみ。
- `flutter test`: 成功。全 66 tests passed。
- `dart analyze`: 成功扱い（exit 0）。info レベル指摘 233 件あり。主な内容は `deprecated_member_use`, `avoid_print`, `curly_braces_in_flow_control_structures`, `unnecessary_import`。
- `flutter devices`: 成功。`iPhone 16 Plus`, `macOS`, `Chrome` を検出。
- `flutter run -d 85A9DAD2-F28D-49DD-8355-A61444AEB3B7 --no-pub`: 成功。iPhone 16 Plus Simulator で Xcode build 完了、Dart VM Service 起動、`App initialization completed successfully` を確認。

### 残課題
- `dart analyze` の info レベル指摘は移動前からの品質課題として残す。今回の独立プロジェクト化の blocker ではない。
- ONNX モデルは Git 管理対象外のため、別環境では `dart run tool/fetch_dexined_model.dart` による再取得が必要。

## 2026-05-01 ユーザーフロー図ドキュメント化

### 実施内容
- `docs/plans/user_flow_diagrams.md` を新規追加し、仕様と実装から読み取れるユーザーロール、画面、操作、分岐条件、バリデーション、想定補完、不明点を整理した。
- 機能カテゴリごとにMermaid `flowchart TD` のコードブロックを分割して追加した。
- 認証、管理者、決済、Push通知、設定画面、履歴画面など、仕様またはUI実装から断定できない領域は不明点または対象外として明示した。
- `docs/plans/plans.md` に今回の文書化方針を追記した。

### 検証結果
- `sed -n '1,220p' .agent/DOCS.md`: 成功。文書管理ポリシーを確認した。
- `sed -n '1,220p' docs/plans/manual.md`: 成功。manual入口と関連配置を確認した。
- `git status --short`: 成功。作業開始時点で未コミット差分なしを確認した。
- `rg -n "^(```mermaid|flowchart TD|## |### )" docs/plans/user_flow_diagrams.md`: 失敗。シェルのバッククォート解釈によるクォートエラーで、ファイル内容起因ではない。
- `rg -n '^(```mermaid|flowchart TD|## |### )' docs/plans/user_flow_diagrams.md`: 成功。見出しとMermaidブロック位置を確認した。
- `rg -c '^```mermaid' docs/plans/user_flow_diagrams.md`: 成功。Mermaidブロック数は9。
- `rg -c '^flowchart TD' docs/plans/user_flow_diagrams.md`: 成功。`flowchart TD` は9件。
- `git diff --check`: 成功。空白エラーなし。
- `wc -l docs/plans/user_flow_diagrams.md`: 成功。591行。

### 残課題
- Mermaidレンダラーによる描画確認は未実施。Markdownとしての保存と構文上の安全性を優先して確認した。
- 設定画面、履歴画面、処理キャンセルUIなど未実装領域は、追加仕様確定後にフロー図を更新する。

## 2026-05-04 輪郭線抽出調査資料の取り込み

### 実施内容
- 今後の実装検討用資料として、`<local-research-source>` を `docs/plans/research/edge_contour_detection_survey_2026.md` にコピーした。
- `docs/plans/research/` を、計画・要件・運用マニュアルとは分離した調査資料置き場として追加した。

### 検証結果
- `sed -n '1,220p' .agent/DOCS.md`: 成功。文書管理ポリシーと canonical documents の更新ルールを確認した。
- `find docs/plans -maxdepth 3 -type d | sort`: 成功。既存の `docs/plans/` 配下構造を確認した。
- `diff -q <local-research-source> docs/plans/research/edge_contour_detection_survey_2026.md`: 成功。コピー元とコピー先に差分なし。
- `wc -l docs/plans/research/edge_contour_detection_survey_2026.md`: 成功。コピー先は 499 行。

### 残課題
- 調査資料の内容精査、採用候補手法の比較、実装タスク化は未実施。

## 2026-05-05 2段階線画変換への輪郭線抽出方式追加計画

### 実施内容
- `AGENTS.md`、`.agent/DOCS.md`、`.agent/PLANS.md`、planning / implementation / verification ルールを確認した。
- `docs/plans/research/edge_contour_detection_survey_2026.md` を読み、追加候補方式を端末内 v1 候補、PoC 候補、研究追跡候補へ分類した。
- 既存の2段階変換フローを `docs/plans/designs.md` と `lib/` 配下の実装から確認した。
- PiDiNet、DexiNed、MEMO、MatchED、EasyControlEdge、EDMB、SAUGE、TRACE、MS2Edge、DDN の外部一次情報または公式実装を確認した。
- `docs/plans/execplans/add_edge_contour_methods_to_two_stage_lineart.md` を新規作成した。
- `docs/plans/plans.md` に今回の計画決定を追記した。

### 外部調査結果
- PiDiNet: 公式 GitHub と ICCV 2021 論文を確認。軽量・高速で checkpoint があり、v1 の最有力候補とした。
- DexiNed: 公式 GitHub と OpenCV Hugging Face 配布モデルを確認。既存実装の基準線として維持する。
- MEMO: arXiv を確認。crisp edge の最新候補だが、公式実装未確認かつ DINOv2 系の重い構成のため watchlist とした。
- MatchED: arXiv、project page、GitHub を確認。GitHub は `Coming Soon...` のみで、実装依存にしない。
- EasyControlEdge: arXiv を確認。foundation model fine-tuning のため端末内 v1 には重い。
- EDMB / SAUGE / DDN: 公式実装を確認。PyTorch / Mamba / SAM / CAFormer 依存があり、ONNX 互換性と端末速度検証前は PoC 扱いにする。
- TRACE: arXiv と GitHub を確認。コード・モデル公開予定表記のため実装依存にしない。
- MS2Edge: arXiv を確認。SNN による省電力候補だが公式実装未確認のため研究追跡に留める。

### 検証結果
- `git status --short`: 成功。作業開始時点で未コミット差分なしを確認した。
- `sed -n '1,220p' docs/plans/implementation_summary.md`: 成功。既存の実施記録形式を確認した。
- `sed -n '1,180p' docs/plans/plans.md`: 成功。既存の計画ログ形式を確認した。
- `apply_patch`: 成功。ExecPlan 新規作成、`plans.md` 追記、`implementation_summary.md` 追記を行った。
- `rg -n "PiDiNet|MEMO|MatchED|EasyControlEdge|EDMB|SAUGE|TRACE|MS2Edge|DDN|確認日" docs/plans/execplans/add_edge_contour_methods_to_two_stage_lineart.md`: 成功。対象資料の方式と外部確認日が計画書に含まれることを確認した。
- `rg -n "輪郭線抽出方式追加|PiDiNet線画|add_edge_contour_methods_to_two_stage_lineart" docs/plans/plans.md docs/plans/implementation_summary.md`: 成功。計画ログと実施記録に今回の計画が記録されていることを確認した。
- `git diff --check`: 成功。空白エラーなし。
- `git status --short`: 成功。変更対象が `docs/plans/execplans/add_edge_contour_methods_to_two_stage_lineart.md`、`docs/plans/plans.md`、`docs/plans/implementation_summary.md` に限定されていることを確認した。

### 残課題
- PiDiNet の公式 checkpoint から Flutter ONNX Runtime 互換モデルを再現 export できるかは未確認。
- PiDiNet checkpoint / export 済み ONNX のライセンスと再配布可否は未確認。
- MEMO、MatchED、TRACE の公式コード・重み公開状況は将来再確認が必要。
- 実装変更は未実施。

## 2026-05-05 PiDiNet線画方式追加

### 実施内容
- 2段階変換の第1段に `PiDiNet線画` を追加した。
- `LineArtAlgorithm.pidinet`、`LineArtPreset.pidinet`、`LineArtParameters.pidinetDefaults` を追加した。
- `PidinetOnnxLineArtService` を追加し、RGB正規化、ONNX推論、probability/logit後処理、二値化、線幅反映を実装した。
- `LineArtProcessor.processToLineArt()` に PiDiNet ONNX 分岐を追加し、metadataにmodel asset、input/output、shape、checkpoint SHA256、license policy、threshold、lineThicknessを保存するようにした。
- `lineArtPresetsProvider` と `LineArtConversionScreen` を更新し、`PiDiNet線画` カードを通常UIに追加した。DexiNed調整シートはDexiNed専用のまま維持した。
- `tool/export_pidinet_onnx.py` を追加し、公式 PiDiNet source archive と `table5_pidinet.pth` から `assets/models/pidinet_table5_carv4_ort.onnx` を生成できるようにした。
- `test/pidinet_line_art_test.dart` を追加し、PiDiNet後処理、線幅、logit対応、JSON round-trip、metadataを検証した。
- `test/dexined_line_art_test.dart` を更新し、既存DexiNed挙動とPiDiNetプリセット表示を検証した。
- `docs/plans/requirements.md`、`docs/plans/designs.md`、`docs/plans/plans.md`、`docs/plans/open_questions.md`、ExecPlanを同期した。

### 外部確認・モデル生成
- PiDiNet公式 GitHub: `https://github.com/hellozhuo/pidinet`
- 使用 checkpoint: `trained_models/table5_pidinet.pth`
- checkpoint SHA256: `80860ac267258b5f27486e0ef152a211d0b08120f62aeb185a050acc30da486c`
- 生成モデル: `assets/models/pidinet_table5_carv4_ort.onnx`
- 生成モデルは Git 管理対象外。別環境では `python3 -m pip install onnx` 後に `python3 tool/export_pidinet_onnx.py` を実行する。
- 公式 LICENSE は研究目的・商用利用要連絡の文言とMIT文面が混在するため、今回はユーザー判断により非商用前提で通常UI公開とした。

### 検証結果
- `dart format lib/domain/entities/line_art_entity.dart lib/domain/usecases/line_art_processing_usecase.dart lib/infrastructure/services/line_art_processor.dart lib/infrastructure/services/pidinet_onnx_line_art_service.dart lib/presentation/providers/line_art_processing_provider.dart lib/presentation/screens/line_art_conversion_screen.dart test/dexined_line_art_test.dart test/pidinet_line_art_test.dart`: 成功。
- `flutter test test/dexined_line_art_test.dart test/pidinet_line_art_test.dart`: 成功。14 tests passed。
- `python3 tool/export_pidinet_onnx.py`: 初回は `onnx` 未導入で失敗。`python3 -m pip install --user onnx` 後、sandbox内ネットワーク制限で失敗。承認付き再実行後、DataParallel由来の `module.` prefix不一致で失敗したため、script側でprefix正規化を追加した。
- `python3 tool/export_pidinet_onnx.py`: 成功。公式source archive/checkpointを取得し、SHA256検証後に `assets/models/pidinet_table5_carv4_ort.onnx` を生成した。
- `flutter test`: 成功。全 71 tests passed。
- `dart analyze`: 成功扱い（exit 0）。既存同様 info レベル指摘 233 件あり。主な内容は `deprecated_member_use`, `avoid_print`, `curly_braces_in_flow_control_structures`, `unnecessary_import`。

### 残課題
- iOS Simulator / 実機での `PiDiNet線画 -> 星座に変換 -> 保存/共有対象画像生成` smoke test は未実施。
- PiDiNet の商用利用可否は公式 LICENSE の混在表記が残るため、商用公開時は著者確認が必要。

## 2026-05-05 PiDiNet線画カード表示順調整

### 実施内容
- iPhone画面で `PiDiNet線画` を見つけやすくするため、`lineArtPresetsProvider` の表示順を `DexiNed線画`、`PiDiNet線画`、`写真`、`イラスト`、`風景`、`鉛筆スケッチ` に変更した。
- Widget test を更新し、初期表示で `DexiNed線画` と `PiDiNet線画` が見えること、スクロール後に既存の `写真` カードも表示されることを確認するようにした。

### 検証結果
- `dart format lib/presentation/providers/line_art_processing_provider.dart test/dexined_line_art_test.dart`: 成功。
- `flutter test test/dexined_line_art_test.dart test/pidinet_line_art_test.dart`: 成功。14 tests passed。

## 2026-06-05 GitHub公開public-readiness整備

### 実施内容
- public maintenance reviewpublic-readinessに、GitHub 公開候補として `seizani_app` を整備した。
- `README.md` を公開向けに更新し、目的、主要機能、ONNX モデル取得/生成方針、検証コマンド、保守方針、ライセンス導線を明記した。
- `pubspec.yaml` の説明を Flutter 初期値から、写真を線画・星座風画像へ変換する on-device ONNX inference app の説明へ更新した。
- `LICENSE` を追加し、MIT License として公開できる状態にした。
- `.github/workflows/flutter-ci.yml` を追加し、push / pull request で `flutter pub get`、`dart analyze`、`flutter test` を実行する最小 CI を定義した。
- `PiDiNet線画` 表示順調整後に `写真` カードが初期表示外になるため、`test/line_art_star_decoration_test.dart` にスクロール操作を追加して既存テストを現 UI に合わせた。

### 公開前衛生確認
- Git 管理対象に `.DS_Store`、ONNX モデル本体、coverage 出力、build 出力が含まれていないことを確認した。
- `rg` による秘密情報スキャンで、認証情報らしい値は検出されなかった。ヒットは `Task-Adaptive`、`relevant`、`tokens` などの一般語のみ。
- `assets/models/*.onnx` は `.gitignore` 対象のまま維持し、モデル本体は再配布せず取得/生成手順だけを README に記載した。

### 検証結果
- `git status --short --branch`: 成功。作業開始時点の PiDiNet 関連未コミット差分と、今回追加した公開整備差分を確認した。
- `git ls-files | rg '\.DS_Store$|assets/models|coverage|build'`: 成功。Git 管理対象の該当ヒットは `assets/models/.gitkeep` と Gradle build script のみ。
- `rg -n "(ghp_|github_pat_|sk-|OPENAI_API_KEY|api[_-]?key|token|password|secret|client_secret|private_key)" . -S`: 成功。認証情報らしい値は検出されなかった。
- `flutter pub get`: 成功。依存関係を解決済み。更新可能パッケージの通知のみ。
- `dart format test/line_art_star_decoration_test.dart`: 成功。1ファイル確認、変更なし。
- `dart analyze`: 成功扱い（exit 0）。既存 info レベル指摘 699 件あり。主な内容は `unnecessary_import`、`deprecated_member_use`、`prefer_initializing_formals`、`avoid_print`、`curly_braces_in_flow_control_structures`。
- `flutter test test/line_art_star_decoration_test.dart`: 成功。5 tests passed。
- `flutter test test/dexined_line_art_test.dart test/pidinet_line_art_test.dart`: 成功。14 tests passed。
- `flutter test --concurrency=1`: 成功。全 71 tests passed。
- `git diff --check`: 成功。空白エラーなし。

### 残課題
- GitHub remote 作成、commit、push、GitHub repo metadata 設定はこの記録時点では未完了。
- `dart analyze` の info レベル指摘は既存品質課題として残す。
- PiDiNet の商用利用可否は公式 LICENSE の混在表記が残るため、商用公開時は著者確認が必要。
