# requirements.md
- 最終更新日: 2026-05-05
- バージョン: 1.0

## 文書管理
このプロジェクトの文書管理ルールは `.agent/DOCS.md` に従う。

## DexiNed端末内線画変換

### 機能要件
- REQ-FUNC-001: `seizani_app` の既存「画像 → 線画 → 星座」経路は維持すること。
- REQ-FUNC-002: 線画変換プリセットに `DexiNed線画` を追加し、既存の `写真`、`イラスト`、`風景`、`鉛筆スケッチ` を残すこと。
- REQ-FUNC-003: `DexiNed線画` 選択時のみ端末内ONNX推論で線画PNGを生成すること。
- REQ-FUNC-004: DexiNedモデル本体はgit管理対象にせず、取得スクリプトとSHA256検証で再現可能にすること。

### 非機能要件
- REQ-NFR-001: iOS最小対応はONNX Runtime要件に合わせて16.0にすること。
- REQ-NFR-002: Android向けにONNX RuntimeのProGuard keep ruleを用意すること。
- REQ-NFR-003: DexiNedの後処理、JSON永続化、プリセット公開をテストで検証すること。

### 受け入れ条件
- AC-001: `LineArtAlgorithm.dexined` がJSON round-tripできる。
- AC-002: `DexiNed線画` が `lineArtPresetsProvider` から選べる。
- AC-003: `DexiNedOnnxLineArtService` が `assets/models/edge_detection_dexined_2024sep_ort.onnx` を遅延ロードする。
- AC-004: `tool/fetch_dexined_model.dart` がOpenCV配布ONNXを取得し、SHA256 `a50d01dc8481549c7dedb9eb3e0123b810a016520df75e4669a504609982cdd0` を検証する。

## DexiNed調整UI

### 機能要件
- REQ-FUNC-005: 既存のシンプル版線画変換経路と既存プリセットの操作感を維持すること。
- REQ-FUNC-006: `DexiNed線画` 選択時だけ、線画生成前に調整UIを表示すること。
- REQ-FUNC-007: DexiNed調整UIで `線の量`、`ノイズ抑制`、`線の太さ` を変更できること。
- REQ-FUNC-008: DexiNedで生成した線画は、`星座に変換` からシンプル版の星装飾方式で星座化できること。

### 非機能要件
- REQ-NFR-004: DexiNed調整値は `LineArtParameters` とmetadata JSONに保存でき、旧JSONはデフォルト値で復元できること。
- REQ-NFR-005: DexiNed調整UI追加後もSobel/Canny/XDoG/Pencil/Adaptive Edgeの処理分岐を変更しないこと。

### 受け入れ条件
- AC-005: `LineArtParameters.toJson/fromJson` が `dexinedPercentile`、`dexinedMinThreshold`、`lineThickness` を保持する。
- AC-006: `DexiNed線画` カードをタップすると調整シートが開く。
- AC-007: `写真`、`イラスト`、`風景`、`鉛筆スケッチ` は従来どおりカードタップで線画変換を開始する。
- AC-008: DexiNed後処理で `lineThickness` を上げると黒線ピクセルが増える。

## シンプル版星座変換方式への復帰

### 機能要件
- REQ-FUNC-009: DexiNed端末内ONNX線画変換と調整UIは変更しないこと。
- REQ-FUNC-010: 2段階変換後の `星座に変換` は、旧シンプル版の線画星装飾方式を使うこと。
- REQ-FUNC-011: 現在の骨格抽出/ネットワーク型 `processLineArtToConstellation()` は削除せず、2段階変換後のボタンからは呼ばないこと。
- REQ-FUNC-012: 星座変換時に `線の太さ閾値`、`星密度`、`星サイズ最小/最大`、`明るさ`、`グロー` を調整できること。

### 非機能要件
- REQ-NFR-006: 旧シンプル版の `StarDecorationParams` デフォルト値を維持すること。
- REQ-NFR-007: 装飾済み画像の保存/共有は、シンプル版の出力PNGを対象にすること。

### 受け入れ条件
- AC-009: 線画生成後の画面にシンプル版星座変換の調整UIが表示される。
- AC-010: `星座に変換` 実行時に `decorateLineArt()` が呼ばれ、`processLineArt()` は呼ばれない。
- AC-011: 生成後も調整値を変更して再生成できる。
- AC-012: `StarDecorationParams` と `LineArtStarDecorator` の単体テストが通る。

## PiDiNet端末内線画変換

### 機能要件
- REQ-FUNC-013: 線画変換プリセットに `PiDiNet線画` を追加し、既存の `DexiNed線画`、`写真`、`イラスト`、`風景`、`鉛筆スケッチ` を残すこと。
- REQ-FUNC-014: `PiDiNet線画` 選択時は端末内ONNX推論で黒線白背景の線画PNGを生成すること。
- REQ-FUNC-015: `PiDiNet線画` は第1段の線画変換だけに追加し、第2段の `decorateLineArt()` / `LineArtStarDecorator` 経路を変更しないこと。
- REQ-FUNC-016: PiDiNetモデル本体はgit管理対象にせず、公式 checkpoint からのONNX export手順とSHA256検証で再現可能にすること。

### 非機能要件
- REQ-NFR-008: PiDiNet checkpoint は非商用前提で通常UIに公開し、license policy をmetadataと実装記録に残すこと。
- REQ-NFR-009: PiDiNet専用調整値はv1では追加せず、既存の `edgeThreshold`、`lineThickness`、`contrast`、`smoothLines` を使うこと。
- REQ-NFR-010: PiDiNetの後処理、JSON永続化、プリセット公開をテストで検証すること。

### 受け入れ条件
- AC-013: `LineArtAlgorithm.pidinet` がJSON round-tripできる。
- AC-014: `PiDiNet線画` が `lineArtPresetsProvider` から選べる。
- AC-015: `PidinetOnnxLineArtService` が `assets/models/pidinet_table5_carv4_ort.onnx` を遅延ロードする。
- AC-016: `tool/export_pidinet_onnx.py` が公式 `table5_pidinet.pth` のSHA256 `80860ac267258b5f27486e0ef152a211d0b08120f62aeb185a050acc30da486c` を検証し、ONNXを生成できる。
- AC-017: PiDiNet後処理で `lineThickness` を上げると黒線ピクセルが増える。
