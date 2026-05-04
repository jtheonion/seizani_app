# 2段階線画変換への輪郭線抽出方式追加 ExecPlan

## Purpose / Big Picture
`docs/plans/research/edge_contour_detection_survey_2026.md` の輪郭線抽出調査を、`seizani_app` の「画像 -> 線画 -> 星装飾」2段階変換へ安全に反映するための実装計画を固定する。

この計画の v1 実装対象は第1段の線画変換方式追加に限定する。第2段の `LineArtStarDecorator` / `decorateLineArt()` 経路は維持し、既存の `DexiNed線画`、写真、イラスト、風景、鉛筆スケッチの操作感を壊さない。

## Progress
- [x] repo-local ルールを確認した。
- [x] 対象調査資料を確認した。
- [x] 既存の2段階線画変換フローを確認した。
- [x] 外部一次情報を確認し、実装候補を分類した。
- [x] 実装計画を作成した。
- [ ] 将来実装時に requirements / open questions を同期する。
- [ ] 将来実装時にコード、テスト、モデル取得手順を追加する。
- [ ] 将来実装時に検証結果を `docs/plans/implementation_summary.md` へ記録する。

## Surprises & Discoveries
- 既存実装では、第1段は `LineArtAlgorithm` と `LineArtProcessor.processToLineArt()`、第2段は `LineArtStarDecorator` に分離されている。追加方式は第1段だけへ閉じられる。
- `DexiNedOnnxLineArtService` はコード上では `assets/models/edge_detection_dexined_2024sep_ort.onnx` を参照している。一方、`README.md` や一部ドキュメントには元モデル `edge_detection_dexined_2024sep.onnx` の記載が残るため、将来実装時に既存ドキュメント整合も確認する。
- MatchED の公式 GitHub は確認日時点で `Coming Soon...` の README のみで、実装依存にはできない。
- TRACE の公式 GitHub も確認日時点でコード・モデル公開予定のままなので、実装依存にはできない。
- PiDiNet は公式実装と checkpoint があり、既存の ONNX Runtime 構成へ持ち込みやすい。ただし公式 checkpoint から Flutter ONNX Runtime 互換モデルを再現 export できることを実装開始条件にする。

## Decision Log
- D1: v1 の実装対象は `PiDiNet線画` 追加に絞る。
- D2: DexiNed は既存実装を基準線として維持し、今回の追加方式では置き換えない。
- D3: MEMO、MatchED、EasyControlEdge、EDMB、SAUGE、TRACE、MS2Edge、DDN は watchlist / PoC 扱いにし、本番 UI には出さない。
- D4: community 配布 ONNX を production 依存にしない。公式実装または公式 checkpoint から再現できるモデルだけを候補にする。
- D5: モデル本体は DexiNed と同じく Git 管理対象外にし、取得・変換手順と SHA256 検証で再現可能にする。
- D6: 2段階変換の第2段 `decorateLineArt()` は変更しない。

## Outcomes & Retrospective
- 現時点では計画書作成のみ完了。実装は未実施。
- 調査資料の方式は、端末内 v1 候補、PoC 候補、研究追跡候補に分類できた。
- 最新研究の多くはコード未公開、重い foundation model、学習方式寄りであり、Flutter 端末内処理へ直結させるにはリスクが高い。

## Context and Orientation
- ルール:
  - `AGENTS.md`
  - `.agent/DOCS.md`
  - `.agent/PLANS.md`
  - `.agent/modules/planning.md`
  - `.agent/modules/implementation.md`
  - `.agent/modules/verification.md`
- 対象調査資料:
  - `docs/plans/research/edge_contour_detection_survey_2026.md`
- 既存設計:
  - `docs/plans/designs.md`
  - `docs/plans/plans.md`
  - `docs/plans/requirements.md`
- 主な実装接点:
  - `lib/domain/entities/line_art_entity.dart`
  - `lib/domain/usecases/line_art_processing_usecase.dart`
  - `lib/infrastructure/services/line_art_processor.dart`
  - `lib/infrastructure/services/dexined_onnx_line_art_service.dart`
  - `lib/presentation/providers/line_art_processing_provider.dart`
  - `lib/presentation/screens/line_art_conversion_screen.dart`

## 対象資料から追加候補となる方式の要約
| 方式 | 資料内での位置づけ | 実装判断 |
|---|---|---|
| DexiNed | 実装・比較目的、漫画・線画抽出用途の実用候補 | 既存実装を維持。追加方式の基準線にする。 |
| PiDiNet | 軽量・高速・モバイル寄り候補 | v1 採用候補。公式 checkpoint から ONNX export できる場合だけ実装する。 |
| MEMO | 2026 crisp edge の上位候補 | 研究追跡。公式実装・軽量推論経路が確認できるまで実装しない。 |
| MatchED | crisp edge supervision の最新候補 | 研究追跡。コード未公開のため実装しない。 |
| EasyControlEdge | foundation model fine-tuning 候補 | PoC 候補。端末内 v1 には重い。 |
| EDMB / DDN | Mamba / CAFormer 系の高精度候補 | PoC 候補。ONNX 互換性と速度検証が必要。 |
| SAUGE / Taming SAM 系 | SAM を使う多粒度境界候補 | PoC 候補。SAM 依存が重いため本番 UI には出さない。 |
| TRACE | diffusion self-attention 由来の instance edge 候補 | 研究追跡。コード・モデル未公開のため実装しない。 |
| MS2Edge | SNN による crisp / 省電力候補 | 研究追跡。公式実装確認後に再評価する。 |

## 既存の2段階線画変換フローとの関係
- 第1段:
  - `LineArtConversionScreen` のプリセットカードから `LineArtParameters` を選ぶ。
  - `LineArtProcessingNotifier.startImageToLineArtProcessing()` が `LineArtProcessingUseCase.processImage()` を呼ぶ。
  - `ProcessingRepositoryImpl.processImageToLineArt()` 経由で `LineArtProcessor.processToLineArt()` が線画 PNG を生成する。
- 第2段:
  - 線画生成後の `星座に変換` は `LineArtStarDecorationUseCase.decorate()` を呼ぶ。
  - repository では `decorateLineArt()` から `LineArtStarDecorator.decorate()` を使う。
  - 旧骨格抽出 / ネットワーク型の `processLineArt()` は2段階画面の通常経路では呼ばない。
- PiDiNet は第1段の新しい `LineArtAlgorithm` として追加し、第2段の入力 `LineArtEntity.lineArtImageBytes` の形式を黒線白背景 PNG に揃える。

## Plan of Work
1. 要件・未決事項を同期する。
2. PiDiNet 公式 checkpoint とライセンスを確認する。
3. 公式 checkpoint から ONNX export し、Flutter ONNX Runtime で読み込めることを確認する。
4. `PidinetOnnxLineArtService` を追加する。
5. `LineArtAlgorithm.pidinet`、`LineArtPreset.pidinet`、`PiDiNet線画` プリセットを追加する。
6. 2段階変換 UI に `PiDiNet線画` カードを追加する。
7. テストと手動 smoke test を実施する。
8. canonical documents を更新する。

## Concrete Steps
1. `docs/plans/requirements.md` に確定要件を追記する。
   - `PiDiNet線画` は第1段の線画方式として追加する。
   - モデル本体は Git 管理しない。
   - 公式 checkpoint から再現できない場合は実装を止める。
2. `docs/plans/open_questions.md` に未決事項を追記する。
   - PiDiNet checkpoint / export 済み ONNX のライセンス。
   - Flutter ONNX Runtime 互換 export の可否。
   - iOS / Android の実測処理時間とメモリ。
3. モデル取得・変換手順を追加する。
   - `tool/fetch_pidinet_model.dart` または `tool/export_pidinet_onnx.md` を作る。
   - 取得元 URL、確認日、SHA256、変換コマンド、入力名、出力名、入力 shape を記録する。
4. domain を更新する。
   - `LineArtAlgorithm.pidinet('PiDiNet線画')` を追加する。
   - `LineArtPreset.pidinet` を追加する。
   - `LineArtParameters` は既存の `edgeThreshold`、`lineThickness`、`contrast`、`smoothLines` を使う。PiDiNet 専用値は v1 では追加しない。
5. infrastructure を更新する。
   - `PidinetOnnxLineArtService` を追加し、入力前処理、推論、sigmoid / normalization / threshold / line thickness の後処理を実装する。
   - `LineArtProcessor.processToLineArt()` に PiDiNet 分岐を追加する。
   - `LineArtMetadata.parameters` に model asset、input / output name、input shape、threshold、line thickness を保存する。
6. presentation を更新する。
   - `lineArtPresetsProvider` に `PiDiNet線画` を追加する。
   - `_getAlgorithmIcon()` に PiDiNet 用 icon を追加する。
   - PiDiNet カードは v1 では即時生成にする。DexiNed 調整 sheet は流用しない。
7. tests を追加・更新する。
   - `test/pidinet_line_art_test.dart` を追加する。
   - `test/dexined_line_art_test.dart` のプリセット一覧期待値を更新する。
   - Widget test で `PiDiNet線画` 表示を確認する。
8. docs を同期する。
   - `docs/plans/designs.md` に PiDiNed 線画変換設計を追記する。
   - `docs/plans/plans.md` に計画決定を追記する。
   - `docs/plans/implementation_summary.md` に実施内容と検証結果を追記する。

## Validation and Acceptance
### 計画書作成時の検証
- `rg -n "PiDiNet|MEMO|MatchED|EasyControlEdge|EDMB|SAUGE|TRACE|MS2Edge|DDN|確認日" docs/plans/execplans/add_edge_contour_methods_to_two_stage_lineart.md`
- `rg -n "輪郭線抽出方式追加|PiDiNet線画" docs/plans/plans.md docs/plans/implementation_summary.md`
- `git diff --check`
- `git status --short`

### 将来実装時の検証
- `flutter test test/dexined_line_art_test.dart`
- `flutter test test/pidinet_line_art_test.dart`
- `flutter test`
- `dart analyze`
- モデル配置済み環境で、iOS Simulator または web-server により `PiDiNet線画 -> 星座に変換 -> 保存/共有対象画像生成` を smoke test する。

### 受け入れ条件
- `PiDiNet線画` が2段階変換の第1段プリセットとして表示される。
- `PiDiNet線画` は黒線白背景 PNG の `LineArtEntity` を生成する。
- `PiDiNet線画` 生成後、既存の `星座に変換` が `decorateLineArt()` を使う。
- 既存の `DexiNed線画` と既存プリセットの挙動が変わらない。
- モデル未配置時はクラッシュせず、線画変換失敗としてユーザーにエラーが返る。
- モデル取得・変換元 URL、SHA256、確認日、ライセンス確認結果が記録される。

## Idempotence and Recovery
- コード追加前に ONNX export とライセンスが確認できない場合、実装を開始せず `open_questions.md` に blocker として残す。
- モデル本体は Git 管理しないため、再取得スクリプトまたは手順は既存 DexiNed と同じく冪等にする。
- PiDiNet 分岐で不具合が出た場合、`lineArtPresetsProvider` から `PiDiNet線画` を外せば既存フローへ戻せる。
- DexiNed、既存 Dart アルゴリズム、第2段の星装飾は rollback 対象にしない。

## Artifacts and Notes
### 外部調査記録
確認日: 2026-05-05 JST

| URL | 種別 | 要約 |
|---|---|---|
| https://github.com/hellozhuo/pidinet | 公式実装 | PiDiNet の PyTorch 実装、checkpoint、評価・実行手順が確認できる。v1 の最有力候補。 |
| https://openaccess.thecvf.com/content/ICCV2021/html/Su_Pixel_Difference_Networks_for_Efficient_Edge_Detection_ICCV_2021_paper.html | 論文 | Pixel Difference Convolution による軽量 edge detection。モバイル候補として調査資料の方向と合う。 |
| https://github.com/xavysp/DexiNed | 公式実装 | 既存実装済み DexiNed の upstream。基準線として維持する。 |
| https://huggingface.co/opencv/edge_detection_dexined | 配布モデル | OpenCV の DexiNed ONNX 配布元。既存 `tool/fetch_dexined_model.dart` の前提。 |
| https://arxiv.org/abs/2603.20782 | 論文 | MEMO は crisp edge に強い最新候補だが、DINOv2 系で端末内 v1 には重い。公式実装は未確認。 |
| https://arxiv.org/abs/2602.20689 | 論文 | MatchED は matching-based supervision で crisp edge を狙うが、推論モデル追加ではなく学習方式寄り。 |
| https://cvpr26-matched.github.io/ | 公式ページ | MatchED の GitHub リンクはあるが、確認時点では code が実質未公開。 |
| https://arxiv.org/abs/2602.16238 | 論文 | EasyControlEdge は foundation model fine-tuning と edge density 制御が特徴。端末内 v1 には重い。 |
| https://arxiv.org/abs/2501.04846 | 論文 | EDMB は Mamba 系 edge detector。高精度候補だが mobile ONNX 互換性検証が必要。 |
| https://github.com/MengyangPu/EDMB | 公式実装 | EDMB の PyTorch 実装。PoC 候補。 |
| https://arxiv.org/abs/2412.12892 | 論文 | SAUGE / Taming SAM は SAM feature で multi-granularity edge を扱う。SAM 依存が重い。 |
| https://github.com/Star-xing1/SAUGE | 公式実装 | SAUGE の PyTorch 実装。端末内 v1 ではなく研究 PoC 候補。 |
| https://arxiv.org/abs/2503.07982 | 論文 | TRACE は diffusion self-attention 由来の instance edge detector。 |
| https://github.com/raoyongming/TRACE | 公式ページ | 確認時点でコード・モデルが公開予定表記のため実装依存にしない。 |
| https://arxiv.org/abs/2511.13735 | 論文 | MS2Edge は SNN による crisp / energy-efficient edge detection。公式実装未確認。 |
| https://github.com/Li-yachuan/DDN | 公式実装 | DDN の PyTorch 実装。高精度候補だが CAFormer / PyTorch 前提で PoC 扱い。 |

### 推測として扱う事項
- PiDiNet は軽量性と公式 checkpoint の存在から Flutter ONNX Runtime へ移植しやすいと推測する。ただし実際の export 成功、入出力名、端末速度は未検証。
- MEMO、EasyControlEdge、SAUGE、TRACE は高品質な線画化へ将来効く可能性があるが、端末内 v1 に入れるにはモデルサイズ・依存・公開状況の不確実性が高い。

## Interfaces and Dependencies
- 追加予定 interface:
  - `LineArtAlgorithm.pidinet`
  - `LineArtPreset.pidinet`
  - `PidinetOnnxLineArtService.process(Uint8List imageBytes, {LineArtParameters parameters})`
- 既存維持 interface:
  - `LineArtProcessor.processToLineArt()`
  - `LineArtProcessingUseCase.processImage()`
  - `ProcessingRepository.decorateLineArt()`
  - `LineArtStarDecorator.decorate()`
- 依存:
  - `flutter_onnxruntime: ^1.7.0`
  - `image: ^4.2.0`
  - PiDiNet 公式 checkpoint と export 手順
  - `assets/models/` の Git 管理対象外運用
