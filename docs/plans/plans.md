# plans.md
- 最終更新日: 2026-05-05
- バージョン: 1.0

## 文書管理
このプロジェクトの文書管理ルールは `.agent/DOCS.md` に従う。

## 計画ログ

### 2026-04-28 DexiNed端末内線画変換

#### 目的
`seizani_app` の本番変換導線に、写真から高品質な抽象線画を生成しやすいDexiNedを追加する。ユーザーは既存の変換カードと同じ画面で `DexiNed線画` を選び、その出力を従来どおり星座変換へ進められる。

#### 決定
- 対象は `seizani_app` とする。
- ONNX Runtimeは `flutter_onnxruntime: ^1.7.0` を使う。
- iOSはONNX Runtime要件に合わせて16.0以上へ引き上げる。
- モデル本体は大容量のためgit管理しない。`tool/fetch_dexined_model.dart` でOpenCV Hugging Face配布モデルを取得し、SHA256を検証する。
- 既存アルゴリズムの処理経路は変更せず、DexiNedだけ専用サービスへ分岐する。

#### 検証
- 新規 `test/dexined_line_art_test.dart` で、後処理、JSON round-trip、プリセット登録を確認する。
- `tool/fetch_dexined_model.dart` でモデル取得とSHA256検証を確認する。モデル本体は `.gitignore` 対象のローカルファイルとして扱う。
- 変更ファイルの `dart analyze` が通ることを確認する。
- 星座生成系の既存失敗を修正し、全体 `flutter test` が通ることを確認する。
- iOS Simulatorで `flutter run` による起動と初期化完了ログを確認する。

### 2026-04-28 DexiNed調整UI追加

#### 目的
既存のDexiNed端末内ONNX線画変換を作り直さず、ユーザーが線画化前に後処理パラメータを調整できるようにする。シンプル版の既存プリセットは操作感を変えず、DexiNedで生成した線画も従来の `星座に変換` 経路へ渡す。

#### 決定
- `LineArtParameters` に `dexinedPercentile`、`dexinedMinThreshold` を追加し、`lineThickness` をDexiNed後処理にも反映する。
- `DexiNed線画` のカードだけ設定シートを開き、既存の `写真`、`イラスト`、`風景`、`鉛筆スケッチ` は従来どおり即時処理する。
- 既存の `DexiNedOnnxLineArtService` と `LineArtProcessor` のDexiNed分岐を利用し、ONNXモデル、入力名、出力名、ORT互換モデルの扱いは維持する。
- metadataには実際に使った `dexinedPercentile`、`dexinedMinThreshold`、`lineThickness` を保存する。

#### 検証
- `LineArtParameters` の新規DexiNed調整値をJSON round-tripと旧JSON復元で確認する。
- DexiNed後処理で強い応答が黒線、背景が白になることと、線の太さ変更で黒線ピクセルが増えることを確認する。
- Widget testで `DexiNed線画` カードが調整シートを開くことを確認する。
- iOS Simulatorでサンプル画像から `DexiNed線画` の調整、線画生成、星座変換まで確認する。

### 2026-04-28 シンプル版星座変換方式への復帰

#### 目的
DexiNed端末内ONNX線画変換と調整UIは維持し、線画生成後の `星座に変換` だけを当初のシンプル版で使っていた線画への星装飾方式へ戻す。現在の骨格抽出/ネットワーク型 `processLineArtToConstellation()` は削除せず、2段階変換後のボタンからは使わない。

#### 決定
- 旧シンプル版の `LineArtStarDecorator`、`StarDecorationParams`、`LineArtDecorationEntity` 相当を `seizani_app` に取り込む。
- `ProcessingRepository.decorateLineArt()` と `LineArtStarDecorationUseCase` を追加し、`LineArtEntity` から装飾済みPNGを生成する。
- `LineArtConversionScreen` の `星座に変換` は、シンプル版星装飾UseCaseを呼ぶ。
- 星座変換時の調整UIは `線の太さ閾値`、`星密度`、`星サイズ最小/最大`、`明るさ`、`グロー` を公開する。

#### 検証
- `StarDecorationParams` のJSON round-tripと旧JSONデフォルト復元を確認する。
- `LineArtStarDecorator` が太い線画に星を追加し、固定seedで決定的に動作し、星密度で星数が増えることを確認する。
- Widget/provider testで、2段階変換後の `星座に変換` が `decorateLineArt()` を使い、`processLineArt()` を呼ばないことを確認する。


### 2026-04-30 seizani_app 独立プロジェクト化

#### 目的
既存作業ツリー配下にあった最新版候補の `seizani_app` を独立プロジェクトとして切り出し、`project_starter_template_v4` 準拠で管理する。

#### 決定
- 移動元は検証完了まで残す。
- 新しい `seizani_app` は独立した Git リポジトリとして管理する。
- Flutter 生成物や `.dart_tool` は作業コピーには残せるが、Git 管理対象外にする。
- DexiNed ONNX モデルは作業コピーには残し、Git には含めない。再取得手順は `README.md` と `QUICKSTART.md` に記載する。
- 文書管理と ExecPlan 運用は `.agent/DOCS.md` と `.agent/PLANS.md` を正本にする。

#### 検証
- ルール文書、canonical documents、アプリ起動に必要な Flutter 構成を確認する。
- `flutter pub get`、`flutter test`、`dart analyze`、起動確認の結果を `implementation_summary.md` に記録する。

### 2026-05-01 ユーザーフロー図ドキュメント化

#### 目的
PM、デザイナー、エンジニア、QAがレビューできる粒度で、`seizani_app` のユーザー操作、画面遷移、状態遷移、権限分岐、入力バリデーション、エラー処理をMermaidフロー図として参照できる状態にする。

#### 決定
- フロー図は新規ドキュメント `docs/plans/user_flow_diagrams.md` に保存する。
- 仕様と実装から読み取れる範囲を正とし、認証、管理者、決済、Push通知、設定画面、履歴画面など未実装または未確認の領域は不明点または対象外として明示する。
- Mermaidは `flowchart TD` を使い、起動、初回利用、メイン機能、2段階変換、保存共有、設定履歴、通知外部連携、エラー例外に分割する。

#### 検証
- Markdown内に機能カテゴリ別のMermaidコードブロックがあることを確認する。
- MermaidノードIDは英数字とアンダースコア中心にし、構文エラーになりやすい長文条件を避ける。

### 2026-05-05 2段階線画変換への輪郭線抽出方式追加計画

#### 目的
`docs/plans/research/edge_contour_detection_survey_2026.md` の調査結果を、既存の「画像 -> 線画 -> 星装飾」2段階変換へ追加するための実装計画として整理する。実装は行わず、端末内実装可能性、既存フローとの境界、検証条件、外部根拠を固定する。

#### 決定
- 計画書は `docs/plans/execplans/add_edge_contour_methods_to_two_stage_lineart.md` に保存する。
- v1 の実装対象候補は `PiDiNet線画` に絞る。既存の `DexiNed線画` は置き換えず、基準線として維持する。
- MEMO、MatchED、EasyControlEdge、EDMB、SAUGE、TRACE、MS2Edge、DDN は、コード公開状況、モデルサイズ、ONNX互換性、端末内処理負荷のリスクにより watchlist / PoC 扱いにする。
- 追加方式は2段階変換の第1段 `LineArtProcessor.processToLineArt()` に閉じ、第2段の `LineArtStarDecorator` / `decorateLineArt()` 経路は変更しない。
- モデル本体は Git 管理せず、公式実装または公式 checkpoint から再現できる取得・変換手順と SHA256 検証を必須にする。

#### 検証
- 計画書に背景、方式要約、既存フローとの関係、実装方針、変更候補ファイル、検証方針、リスク、受け入れ条件、外部根拠 URL と確認日が含まれることを確認する。
- `rg` と `git diff --check` で計画書・計画ログ・実施記録の整合と空白エラーを確認する。

### 2026-05-05 PiDiNet線画方式追加

#### 目的
2段階変換の第1段に `PiDiNet線画` を追加し、軽量な輪郭線抽出方式を既存の `DexiNed線画` と並べて選べるようにする。第2段の `decorateLineArt()` / `LineArtStarDecorator` は維持する。

#### 決定
- `LineArtAlgorithm.pidinet`、`LineArtPreset.pidinet`、`PidinetOnnxLineArtService` を追加する。
- 公式 `table5_pidinet.pth` から `assets/models/pidinet_table5_carv4_ort.onnx` を生成する。checkpoint SHA256 は `80860ac267258b5f27486e0ef152a211d0b08120f62aeb185a050acc30da486c`。
- PiDiNet は非商用前提で通常UIに公開する。公式 LICENSE の混在表記は `open_questions.md` と metadata policy に残す。
- PiDiNet v1 は専用調整値を追加せず、`edgeThreshold`、`lineThickness`、`contrast`、`smoothLines` の既存値だけを使う。
- モデル本体は Git 管理対象外にし、`tool/export_pidinet_onnx.py` で再生成する。

#### 検証
- PiDiNet後処理、JSON round-trip、metadata、プリセット登録、Widget上の表示をテストする。
- `python3 tool/export_pidinet_onnx.py` で公式 checkpoint から ONNX を生成できることを確認する。
- `flutter test` と `dart analyze` を実施する。
