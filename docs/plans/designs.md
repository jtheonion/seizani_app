# designs.md
- 最終更新日: 2026-05-05
- バージョン: 1.0

## 文書管理
このプロジェクトの文書管理ルールは `.agent/DOCS.md` に従う。

## DexiNed端末内線画変換設計

`seizani_app` は `LineArtProcessingUseCase` から `ProcessingRepositoryImpl.processImageToLineArt()` を呼び、最終的に `LineArtProcessor.processToLineArt()` で線画画像を生成する。DexiNedは既存アルゴリズムと同じ `LineArtParameters` で選択できるようにし、`LineArtAlgorithm.dexined` のときだけONNX推論サービスへ分岐する。

`DexiNedOnnxLineArtService` は `flutter_onnxruntime` の `OnnxRuntime.createSessionFromAsset()` で `assets/models/edge_detection_dexined_2024sep_ort.onnx` を遅延ロードする。入力は `img`、出力は `block_cat`、入力形状は `[1, 3, 480, 640]`、出力形状は `[1, 1, 480, 640]` を前提にする。

前処理は画像を640x480へリサイズし、BGR順のFloat32 NCHW配列へ変換して平均値 `[103.5, 116.2, 123.6]` を引く。後処理はONNX出力にsigmoidを適用し、0..255正規化、元サイズへのリサイズ、percentile 92 と最小閾値24による二値化を行い、黒線白背景PNGとして返す。

既存のSobel/Canny/XDoG/Pencil/Adaptive Edgeは従来どおりisolate上のDart画像処理を使う。DexiNedはFlutterプラグインのMethodChannelを使うため、isolateに入れない。

## DexiNed調整UI設計

既存のDexiNed経路を維持し、`LineArtParameters` にDexiNed専用の後処理値を追加する。`dexinedPercentile` はデフォルト92.0、範囲85.0〜98.0で、値を上げるほど採用する線を絞る。`dexinedMinThreshold` はデフォルト24、範囲0〜80で、値を上げるほど弱い応答を背景に寄せる。`lineThickness` は既存パラメータを流用し、DexiNed後処理では二値化後の黒線を太らせる。

UIは `LineArtConversionScreen` の変換方法選択カードを拡張する。`DexiNed線画` のカードだけ設定シートを開き、`線の量`、`ノイズ抑制`、`線の太さ` のスライダーと、`デフォルトに戻す`、`DexiNed線画を生成` を表示する。既存の `写真`、`イラスト`、`風景`、`鉛筆スケッチ` は従来どおりタップで即時に線画変換を開始する。

`LineArtProcessor.processToLineArt()` はDexiNed分岐で `DexiNedOnnxLineArtService.process()` に `LineArtParameters` を渡す。ONNX出力後の `sigmoid → 0..255正規化 → 元サイズリサイズ → percentile/minThreshold二値化 → 線幅反映` を行い、黒線白背景PNGを返す。生成後の `LineArtEntity` は既存と同じ状態管理に入る。

## PiDiNet端末内線画変換設計

`PiDiNet線画` は第1段の追加アルゴリズムとして `LineArtAlgorithm.pidinet` と `LineArtPreset.pidinet` で公開する。`LineArtProcessor.processToLineArt()` はPiDiNet分岐で `PidinetOnnxLineArtService.process()` を呼び、DexiNedと同じくONNX RuntimeのMethodChannelを使うためisolateには入れない。

`PidinetOnnxLineArtService` は `assets/models/pidinet_table5_carv4_ort.onnx` を遅延ロードする。入力は `input`、出力は `edge`、入力形状は `[1, 3, 480, 640]` を前提にする。モデル本体は Git 管理対象外で、`tool/export_pidinet_onnx.py` が公式 `table5_pidinet.pth` のSHA256を検証して生成する。

前処理は公式 PiDiNet dataloader に合わせ、画像を640x480へリサイズし、RGB順のFloat32 NCHW配列へ変換して `ToTensor + mean=[0.485, 0.456, 0.406] / std=[0.229, 0.224, 0.225]` を適用する。後処理はONNX出力をprobabilityまたはlogitとして扱い、元サイズへリサイズ、`contrast`、`edgeThreshold`、`lineThickness` を適用して黒線白背景PNGを返す。

UIでは `PiDiNet線画` カードを通常プリセットとして表示し、DexiNed調整シートは開かず即時生成する。生成後は既存の `星座に変換` ボタンからシンプル版星装飾経路へ進む。

## シンプル版星座変換方式への復帰設計

2段階変換画面の `星座に変換` は、線画専用の骨格抽出/ネットワーク型 `ConstellationProcessor.processLineArtToConstellation()` ではなく、旧シンプル版の `LineArtStarDecorator` 方式を呼び出す。既存の新しい星座変換処理は他経路用に残し、2段階変換後のボタンだけをシンプル版の星装飾UseCaseへ向ける。

`StarDecorationParams` は `lineWidthThreshold`、`starDensity`、`starMinSize`、`starMaxSize`、`starBrightness`、`starGlow`、`starColor`、`seed` を持つ。UIでは `線の太さ閾値`、`星密度`、`星サイズ最小/最大`、`明るさ`、`グロー` を調整できるようにする。デフォルト値は旧シンプル版と同じにする。

処理結果は `LineArtDecorationEntity` として保持する。`LineArtProcessingState` は既存の `ConstellationEntity` を残しつつ、2段階変換の通常結果として `LineArtDecorationEntity.decoratedImageBytes` を表示、保存、共有に使う。
