# user_flow_diagrams.md
- 最終更新日: 2026-05-01
- バージョン: 1.0

## 目的
この文書は、`seizani_app` の仕様と実装から読み取れるユーザー操作、画面遷移、状態遷移、権限分岐、入力バリデーション、エラー処理を、レビュー可能なMermaidフロー図として整理する。

## 1. 抽出した前提情報

### ユーザーロール
- 一般利用者: 画像を選び、星座アートへ変換し、保存または共有するユーザー。
- 管理者、ログインユーザー、課金ユーザー: 仕様および実装からは読み取れない。
- システム側アクター: 端末OS権限、画像ピッカー、共有シート、ローカルストレージ、ONNX Runtime。

### 機能カテゴリ
- 起動、初期化
- 画像選択
- 直接変換
- 2段階変換
- DexiNed線画調整
- 星座装飾調整
- 結果表示、保存、共有
- ローカル保存、履歴、設定の内部処理
- 権限、バリデーション、エラー処理

### 画面一覧
- スプラッシュ画面
- 初期化エラー画面
- ホーム画面
- 画像選択エリア
- 変換方法説明ダイアログ
- 2段階変換画面
- DexiNed線画調整ボトムシート
- 星座変換調整パネル
- 2段階変換エラー表示
- 結果表示エリア
- 設定画面: アイコンのみ存在。遷移は未実装。

### 主な操作
- カメラで撮影
- ギャラリーから選択
- 検証用サンプルを選択
- エラーを閉じる
- 別の画像を選ぶ
- 直接変換
- 2段階変換へ進む
- 変換方法説明を開く、閉じる
- 線画プリセットを選ぶ
- DexiNed調整値を変更する
- DexiNed調整をデフォルトに戻す
- DexiNed線画を生成する
- 2段階変換画面から戻る
- 線画変換をやり直す
- 星座に変換する
- 星座装飾パラメータを変更する
- この設定で再生成する
- 結果を共有する
- 結果を保存する
- 新しい画像で試す

### 主な分岐条件
- 初期化成功か失敗か
- 画像が未選択、選択済み、結果生成済みか
- カメラまたは写真ライブラリ権限が許可されたか
- 画像選択がキャンセルされたか
- 画像がバリデーションを満たすか
- 画像が大きくリサイズ対象か
- 直接変換か2段階変換か
- 線画プリセットがDexiNedかそれ以外か
- 線画変換が成功したか失敗したか
- 星座装飾が成功したか失敗したか
- 結果画像データが存在するか
- Web実行かネイティブ実行か
- 外部ストレージへアクセスできるか

### バリデーション
- 対応形式: JPEG、PNG、WebP、BMP、GIF。
- 最小画像サイズ: 100x100px。
- 最大画像サイズ: 4000x4000px。
- 最大ファイルサイズ: 50MB。
- 許容アスペクト比: 0.1 から 10.0。
- 処理前リサイズ: 1200x1200pxを超える画像は縮小。
- DexiNed調整: 線の量 85.0 から 98.0、ノイズ抑制 0 から 80、線の太さ 1 から 3。
- 星座装飾調整: 線の太さ閾値 0.5 から 8.0、星密度 0.2 から 2.0、星サイズ最小 0.5 から 6.0、星サイズ最大 0.5 から 8.0、明るさ 0 から 1、グロー 0 から 1。

### 想定補完した内容
- 認証機能は存在しないため、認証フローは「なし」として扱う。
- 初回利用フローは、初期化時のローカル設定とユーザー設定の作成、および初回画像選択として扱う。
- 通知フローはPush通知ではなく、進捗表示、SnackBar、エラー表示として扱う。
- 外部連携は、端末OS権限、画像ピッカー、共有シート、ローカルストレージ、ONNX Runtimeを対象にする。
- 通信エラーは通常アプリ操作では登場しない。DexiNedモデル取得スクリプトは開発、セットアップ用途であり、アプリ内ユーザーフロー外とする。

### 不明点
- 設定画面の仕様は未実装。
- 履歴一覧、詳細、削除のUIは未実装。ただしProviderとUseCaseには履歴取得、削除、全削除が存在する。
- 処理中キャンセルUIは見当たらない。
- ログイン、セッション切れ、管理者権限、決済、Push通知は仕様から読み取れない。
- 直接変換の失敗時にホーム画面へエラーメッセージを明示表示するUIは読み取れない。
- 2段階変換エラー画面の「再試行」は実装上 `clearError` のみで、処理再実行ではない可能性がある。
- 星サイズ最小値が最大値を超えた場合の明示バリデーションは読み取れない。

## 2. Mermaidコードブロック

### 認証フロー 兼 起動フロー

```mermaid
flowchart TD
  subgraph User["一般利用者"]
    U_Start["アプリ起動"]
    U_Retry["再試行"]
  end

  subgraph App["アプリ"]
    A_Splash["スプラッシュ"]
    A_Init["初期化"]
    A_SettingsLoad["設定読込"]
    A_PrefsLoad["設定作成"]
    A_Migrate["移行確認"]
    A_Home["ホーム"]
    A_InitError["初期化エラー"]
  end

  U_Start --> A_Splash
  A_Splash --> A_Init
  A_Init --> A_SettingsLoad
  A_SettingsLoad --> A_PrefsLoad
  A_PrefsLoad --> A_Migrate
  A_Migrate --> InitOk{初期化成功}
  InitOk -->|はい| A_Home
  InitOk -->|いいえ| A_InitError
  A_InitError --> U_Retry
  U_Retry --> A_Init

  A_Home --> AuthNone{認証あり}
  AuthNone -->|いいえ| A_Home
```

### 初回利用フロー

```mermaid
flowchart TD
  subgraph User["一般利用者"]
    U_Open["ホーム表示"]
    U_Camera["カメラで撮影"]
    U_Gallery["ギャラリー選択"]
    U_Sample["サンプル選択"]
    U_CloseError["エラーを閉じる"]
  end

  subgraph OS["端末OS"]
    OS_Permission["権限確認"]
    OS_Picker["画像ピッカー"]
  end

  subgraph App["アプリ"]
    A_Select["画像選択エリア"]
    A_Loading["読込中"]
    A_Validate["画像検証"]
    A_Resize["画像リサイズ"]
    A_Preview["画像プレビュー"]
    A_Error["選択エラー表示"]
  end

  U_Open --> A_Select
  A_Select --> U_Camera
  A_Select --> U_Gallery
  A_Select --> U_Sample

  U_Camera --> OS_Permission
  U_Gallery --> OS_Permission
  OS_Permission --> PermOk{権限OK}
  PermOk -->|はい| OS_Picker
  PermOk -->|いいえ| A_Error

  OS_Picker --> Picked{画像あり}
  Picked -->|いいえ| A_Select
  Picked -->|はい| A_Loading

  U_Sample --> A_Loading
  A_Loading --> A_Validate
  A_Validate --> ValidImage{検証OK}
  ValidImage -->|いいえ| A_Error
  ValidImage -->|はい| NeedResize{縮小必要}
  NeedResize -->|はい| A_Resize
  NeedResize -->|いいえ| A_Preview
  A_Resize --> ResizeOk{縮小成功}
  ResizeOk -->|はい| A_Preview
  ResizeOk -->|いいえ| A_Error

  A_Error --> U_CloseError
  U_CloseError --> A_Select
  A_Error --> U_Camera
  A_Error --> U_Gallery
```

### メイン機能フロー

```mermaid
flowchart TD
  subgraph User["一般利用者"]
    U_Direct["直接変換"]
    U_TwoStage["2段階変換"]
    U_Info["説明を開く"]
    U_Clear["別の画像"]
  end

  subgraph Home["ホーム画面"]
    H_NoImage["画像未選択"]
    H_Preview["画像プレビュー"]
    H_InfoDialog["説明ダイアログ"]
    H_Overlay["処理中表示"]
    H_Result["結果表示"]
  end

  subgraph System["処理"]
    S_DirectStart["直接変換開始"]
    S_Preprocess["前処理"]
    S_Edge["エッジ検出"]
    S_Feature["特徴抽出"]
    S_Generate["星座生成"]
    S_Render["画像生成"]
    S_SaveHistory["履歴保存"]
    S_Error["処理エラー"]
  end

  H_NoImage --> H_Preview
  H_Preview --> U_Direct
  H_Preview --> U_TwoStage
  H_Preview --> U_Info
  H_Preview --> U_Clear

  U_Info --> H_InfoDialog
  H_InfoDialog --> H_Preview

  U_Clear --> H_NoImage

  U_Direct --> S_DirectStart
  S_DirectStart --> H_Overlay
  H_Overlay --> S_Preprocess
  S_Preprocess --> S_Edge
  S_Edge --> S_Feature
  S_Feature --> S_Generate
  S_Generate --> S_Render
  S_Render --> DirectOk{変換成功}
  DirectOk -->|はい| S_SaveHistory
  S_SaveHistory --> H_Result
  DirectOk -->|いいえ| S_Error
  S_Error --> H_Preview

  U_TwoStage --> L_Start["2段階変換画面"]
```

### 2段階変換 線画作成フロー

```mermaid
flowchart TD
  subgraph User["一般利用者"]
    U_Open["2段階変換へ進む"]
    U_Back["戻る"]
    U_Reset["やり直し"]
    U_Dexined["DexiNed線画"]
    U_Preset["通常プリセット"]
    U_SheetCancel["シートを閉じる"]
    U_Default["デフォルトに戻す"]
    U_Generate["線画を生成"]
  end

  subgraph Screen["2段階変換画面"]
    L_Initial["元画像表示"]
    L_Presets["変換方法一覧"]
    L_DexSheet["DexiNed調整"]
    L_Progress["線画変換中"]
    L_LineReady["線画完了"]
    L_Error["線画エラー"]
  end

  subgraph System["線画処理"]
    S_Params["パラメータ決定"]
    S_Onnx["DexiNed推論"]
    S_Classical["通常線画処理"]
    S_Post["後処理"]
    S_SaveLine["線画保存"]
  end

  U_Open --> L_Initial
  L_Initial --> L_Presets
  L_Presets --> U_Back
  U_Back --> H_Preview["ホーム画像プレビュー"]

  L_Presets --> U_Dexined
  U_Dexined --> L_DexSheet
  L_DexSheet --> U_SheetCancel
  U_SheetCancel --> L_Presets
  L_DexSheet --> U_Default
  U_Default --> L_DexSheet
  L_DexSheet --> U_Generate

  L_Presets --> U_Preset
  U_Preset --> S_Params
  U_Generate --> S_Params

  S_Params --> IsDexined{DexiNed}
  IsDexined -->|はい| S_Onnx
  IsDexined -->|いいえ| S_Classical
  S_Onnx --> S_Post
  S_Classical --> S_Post
  S_Post --> LineOk{線画成功}
  LineOk -->|はい| S_SaveLine
  S_SaveLine --> L_LineReady
  LineOk -->|いいえ| L_Error

  L_LineReady --> U_Reset
  U_Reset --> L_Initial
  L_Error --> U_Reset
  U_Reset --> L_Initial
```

### 2段階変換 星座装飾フロー

```mermaid
flowchart TD
  subgraph User["一般利用者"]
    U_Adjust["調整値変更"]
    U_Default["デフォルトに戻す"]
    U_Convert["星座に変換"]
    U_Toggle["調整を開閉"]
    U_Regen["この設定で再生成"]
    U_Reset["やり直し"]
  end

  subgraph Screen["2段階変換画面"]
    L_LineReady["線画完了"]
    L_AdjustPanel["星座調整"]
    L_Progress["星座変換中"]
    L_Result["星座結果"]
    L_Error["星座エラー"]
  end

  subgraph System["星装飾処理"]
    S_Params["装飾値決定"]
    S_Analyze["線を解析"]
    S_DrawStars["星を描画"]
    S_Metadata["メタデータ作成"]
  end

  L_LineReady --> L_AdjustPanel
  L_AdjustPanel --> U_Adjust
  U_Adjust --> L_AdjustPanel
  L_AdjustPanel --> U_Default
  U_Default --> L_AdjustPanel
  L_AdjustPanel --> U_Convert

  U_Convert --> S_Params
  S_Params --> L_Progress
  L_Progress --> S_Analyze
  S_Analyze --> S_DrawStars
  S_DrawStars --> DecorOk{装飾成功}
  DecorOk -->|はい| S_Metadata
  S_Metadata --> L_Result
  DecorOk -->|いいえ| L_Error

  L_Result --> U_Toggle
  U_Toggle --> L_AdjustPanel
  L_AdjustPanel --> U_Regen
  U_Regen --> S_Params

  L_LineReady --> U_Reset
  L_Result --> U_Reset
  L_Error --> U_Reset
  U_Reset --> L_Initial["元画像表示"]
```

### 結果の保存 共有フロー

```mermaid
flowchart TD
  subgraph User["一般利用者"]
    U_Share["共有"]
    U_Save["保存"]
    U_New["新しい画像で試す"]
  end

  subgraph Screen["結果表示"]
    R_Direct["直接変換結果"]
    R_TwoStage["2段階変換結果"]
    R_Snack["結果通知"]
    R_Home["画像未選択"]
  end

  subgraph External["外部連携"]
    E_ShareSheet["共有シート"]
    E_StorageDir["外部ストレージ"]
    E_FileWrite["PNG書込"]
  end

  R_Direct --> U_Share
  R_TwoStage --> U_Share
  U_Share --> HasDataShare{画像あり}
  HasDataShare -->|はい| E_ShareSheet
  HasDataShare -->|いいえ| R_Snack
  E_ShareSheet --> ShareOk{共有成功}
  ShareOk -->|はい| R_Direct
  ShareOk -->|いいえ| R_Snack

  R_Direct --> U_Save
  R_TwoStage --> U_Save
  U_Save --> IsWeb{Web実行}
  IsWeb -->|はい| R_Snack
  IsWeb -->|いいえ| HasDataSave{画像あり}
  HasDataSave -->|いいえ| R_Snack
  HasDataSave -->|はい| E_StorageDir
  E_StorageDir --> StorageOk{保存先あり}
  StorageOk -->|いいえ| R_Snack
  StorageOk -->|はい| E_FileWrite
  E_FileWrite --> SaveOk{保存成功}
  SaveOk -->|はい| R_Snack
  SaveOk -->|いいえ| R_Snack

  R_Direct --> U_New
  R_TwoStage --> U_New
  U_New --> R_Home
```

### 設定 履歴 削除フロー

```mermaid
flowchart TD
  subgraph User["一般利用者"]
    U_Settings["設定アイコン"]
    U_History["履歴を見る"]
    U_Delete["履歴削除"]
  end

  subgraph UI["画面"]
    UI_Home["ホーム"]
    UI_NotBuilt["未実装"]
  end

  subgraph Internal["内部機能"]
    I_AppSettings["アプリ設定"]
    I_UserPrefs["ユーザー設定"]
    I_HistoryLoad["履歴取得"]
    I_HistoryDelete["履歴削除"]
    I_LineArtSave["線画保存"]
  end

  UI_Home --> U_Settings
  U_Settings --> UI_NotBuilt

  I_AppSettings --> I_UserPrefs
  I_LineArtSave --> I_HistoryLoad

  U_History --> HistoryUi{画面あり}
  HistoryUi -->|いいえ| UI_NotBuilt
  HistoryUi -->|はい| I_HistoryLoad

  U_Delete --> DeleteUi{画面あり}
  DeleteUi -->|いいえ| UI_NotBuilt
  DeleteUi -->|はい| I_HistoryDelete
```

### 通知 外部連携フロー

```mermaid
flowchart TD
  subgraph User["一般利用者"]
    U_Action["操作"]
    U_See["表示を確認"]
  end

  subgraph App["アプリ通知"]
    A_Overlay["処理中表示"]
    A_Progress["進捗表示"]
    A_Snack["SnackBar"]
    A_ErrorCard["エラー表示"]
  end

  subgraph External["外部サービス"]
    E_Permission["OS権限"]
    E_ImagePicker["画像ピッカー"]
    E_Share["共有シート"]
    E_Storage["端末保存先"]
    E_Onnx["ONNX Runtime"]
    E_LocalStore["SharedPreferences"]
  end

  U_Action --> E_Permission
  E_Permission --> E_ImagePicker
  E_ImagePicker --> A_Overlay
  A_Overlay --> A_Progress
  A_Progress --> E_Onnx
  E_Onnx --> ProcessOk{処理成功}
  ProcessOk -->|はい| A_Snack
  ProcessOk -->|いいえ| A_ErrorCard
  A_Snack --> U_See
  A_ErrorCard --> U_See

  U_Action --> E_Share
  E_Share --> A_Snack

  U_Action --> E_Storage
  E_Storage --> A_Snack

  A_Progress --> E_LocalStore
```

### エラー 例外フロー

```mermaid
flowchart TD
  subgraph ErrorSource["発生箇所"]
    E_Init["初期化失敗"]
    E_Perm["権限拒否"]
    E_Cancel["選択キャンセル"]
    E_Image["画像不正"]
    E_Read["画像読込失敗"]
    E_Line["線画失敗"]
    E_Decor["星装飾失敗"]
    E_Save["保存失敗"]
    E_Share["共有失敗"]
    E_Session["セッション切れ"]
    E_Network["通信失敗"]
  end

  subgraph App["アプリ表示"]
    A_InitError["初期化エラー画面"]
    A_ImageError["選択エラー"]
    A_NoChange["元画面維持"]
    A_TwoStageError["2段階エラー"]
    A_Snack["SnackBar"]
    A_NotApplicable["対象外"]
  end

  subgraph User["一般利用者"]
    U_Retry["再試行"]
    U_Close["閉じる"]
    U_Back["戻る"]
    U_Reopen["再操作"]
  end

  E_Init --> A_InitError
  A_InitError --> U_Retry
  U_Retry --> E_Init

  E_Perm --> A_ImageError
  E_Image --> A_ImageError
  A_ImageError --> U_Close
  U_Close --> A_NoChange
  A_ImageError --> U_Reopen

  E_Cancel --> A_NoChange
  E_Read --> A_Snack

  E_Line --> A_TwoStageError
  E_Decor --> A_TwoStageError
  A_TwoStageError --> U_Retry
  U_Retry --> RetryReal{再実行あり}
  RetryReal -->|不明| A_TwoStageError
  RetryReal -->|想定| A_NoChange

  E_Save --> A_Snack
  E_Share --> A_Snack

  E_Session --> A_NotApplicable
  E_Network --> A_NotApplicable
  A_NotApplicable --> U_Back
```

## 3. 補足

### 図から漏れる可能性がある操作
- 履歴一覧、履歴詳細、履歴削除、全履歴削除は内部Providerに存在するが、画面UIは確認できない。
- 直接変換のキャンセル操作はProvider側にはキャンセル概念があるが、ホーム画面上の操作としては確認できない。
- 設定アイコンはあるが、設定画面遷移はTODOのため図では未実装扱い。
- 初期化時に作られる `autoSave`、`enableNotifications` などの設定は、画面上の操作には接続されていない。

### 追加仕様があると精度が上がる項目
- 設定画面で扱う項目。
- 処理履歴をユーザーに表示するかどうか。
- 処理中キャンセルをUIとして提供するかどうか。
- 直接変換エラー時の表示方針。
- Web、iOS、Androidごとの保存仕様。
- 星サイズ最小値と最大値の整合性ルール。
- DexiNedモデル未配置時のユーザー向けエラーメッセージ。

### 実装前に確認すべき不明点
- 認証、管理者、決済、Push通知は今後も対象外でよいか。
- 設定画面と履歴画面を正式機能にするか。
- 2段階変換エラー画面の「再試行」は、再処理実行に変更するか。
- 保存先をアプリ外部ストレージのPicturesでよいか、端末の写真アプリへ保存したいか。
- Web版で保存ボタンを非表示にする現状仕様でよいか。
