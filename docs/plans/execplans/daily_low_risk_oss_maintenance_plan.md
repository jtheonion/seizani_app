# Daily Low-Risk OSS Maintenance Plan

- 作成日: 2026-06-07
- 更新日: 2026-06-08
- 対象: `seizani_app`
- 状態: 進行中

## Purpose / Big Picture

`seizani_app` を早期段階の OSS として継続保守するため、1 日 1 件、15〜60 分程度で完了できる低リスク改善を積み上げる。優先対象は docs、公開安全性、CI / tests、依存保守、ユーザー体験に限定する。

この計画は、利用規模や外部評価を誇張せず、次の証拠を継続的に増やすことを目的にする。

- active maintenance: 小さな改善、検証、記録が継続している。
- public safety: 個人画像、EXIF、秘密情報、モデル本体を公開しない運用が維持されている。
- documentation quality: README、QUICKSTART、contributor-facing docs、canonical docs が現状に追従している。
- CI / tests: GitHub Actions とローカル検証の状態が確認できる。
- dependency maintenance: 依存更新と脆弱性対応の入口がある。
- UX: 早期段階でも使い勝手の粗さを少しずつ減らす。

## Progress

- [x] 短時間で進められる低リスク改善候補を棚卸しした。
- [x] 1 日 1 件で進められる順序へ整理した。
- [x] 公開安全性と contributor-facing docs を上位に繰り上げた。
- [x] Day 1: `SECURITY.md` を追加し、公開 issue に載せない情報と報告方針を明確化する。
- [ ] Day 2: `MODEL_LICENSES.md` または README / QUICKSTART の model provenance section を追加し、DexiNed / PiDiNet の取得元、SHA256、再配布可否、PiDiNet 商用利用要確認を明確化する。
- [ ] Day 3: ignored artifact と誤 add 防止の safety scan を整備する。
- [ ] Day 4: README に CI status badge と Actions 導線を追加する。
- [ ] Day 5: `pubspec.yaml` の `http` / `dio` と ChromaDB client コメントを棚卸しし、未使用なら削除候補、必要なら用途明確化候補として整理する。
- [ ] Day 6: Dependabot または Renovate の導入方針を決め、依存更新と vulnerability response の入口を作る。
- [ ] Day 7: `.github/ISSUE_TEMPLATE/config.yml` を追加し、blank issue と安全な報告導線を整理する。
- [ ] Day 8: contributor-facing docs を前面化し、内部運用ログの見え方を整理する。
- [ ] Day 9: CHANGELOG / release 導線を追加する。
- [ ] Day 10: `project_checklist.md` / `open_questions.md` / `plans.md` の鮮度を現在の公開保守状態に合わせて更新する。
- [ ] Day 11: maintenance snapshot を実施し、repo 状態、CI、Issue、公開安全性確認を記録する。
- [ ] Day 12: PiDiNet の手動 smoke test を行い、結果または blocker を記録する。
- [ ] Day 13: settings button の TODO を小さく整理し、未実装 UI の違和感を減らす。
- [ ] Day 14: `dart analyze` の info 指摘を 1 カテゴリだけ棚卸しし、削減計画または小修正を行う。
- [ ] Day 15: 月次 maintenance routine を docs に追加し、以後の反復確認手順を固定する。

## Surprises & Discoveries

- GitHub repo は public、MIT License、Issues 有効、topics 設定済みで、`Flutter CI` が存在する。
- open issue はなく、Issue template は個人画像、EXIF、秘密情報、ONNX model binaries を避ける方針を既に含む。
- adoption signal は stars 0、forks 0、open issue 0 と弱い。採用実績は盛らず、early-stage / active maintenance / reference implementation として説明する方針を維持する。
- PiDiNet の license / commercial use は未確定のため、model provenance と再配布しない方針を contributor-facing docs で明確化する必要がある。
- `pubspec.yaml` には `http` / `dio` と ChromaDB client コメントがあり、「ユーザー画像を外部送信しない」方針に対して質問を誘う可能性がある。
- `SECURITY.md`、Dependabot / Renovate、CHANGELOG / release 導線は未配置で、公開安全性・依存保守・継続保守の証拠として追加余地がある。
- 公開 docs は contributor-facing docs と内部運用ログの境界を整理する余地がある。
- `docs/.DS_Store` はローカルに存在するが、`.gitignore` により ignored で Git 管理対象ではない。公開安全性上の blocker ではないが、次回作業時の掃除候補にする。
- `lib/presentation/screens/home_screen.dart` に settings button の TODO が残っている。小さな UX 改善候補として扱う。

## Decision Log

- 2026-06-07: 1 日 1 件の改善は、依存追加なし、モデル本体追加なし、大容量ファイル追加なし、license 変更なしを原則にする。
- 2026-06-07: 最初の 1 週間は docs / CI visibility / public-safety / verification evidence を優先し、大きな機能追加は避ける。
- 2026-06-07: GitHub stars、forks、downloads、採用実績を増やすための見せかけ issue / PR / 投稿は対象外にする。
- 2026-06-07: 各日の完了条件は、実施内容、検証コマンド、結果、必要な canonical docs 同期が揃った状態とする。
- 2026-06-07: `SECURITY.md`、model provenance、ignored artifact safety scan を Day 1〜3 に繰り上げる。
- 2026-06-07: Dependabot / Renovate と CHANGELOG は有用だが、公開安全性と model provenance より後に実施する。
- 2026-06-08: 公開文書と canonical docs には、プロダクトの実装・保守・公開安全性に直接関係しない外部制度の固有情報を書かない。

## Outcomes & Retrospective

### 2026-06-15 Day 1

- `SECURITY.md` を追加し、サポート対象範囲、脆弱性・公開安全性問題の報告方針、public issue に載せない情報、画像処理・ONNX モデル・依存関係・CI の報告観点、モデルファイルを Git 管理しない方針、緊急度の目安を明確化した。
- `README.md` と `CONTRIBUTING.md` から `SECURITY.md` への短い導線を追加した。
- 個人連絡先、秘密情報、認証情報、モデル本体、大容量ファイル、依存追加、license 変更は追加していない。
- docs-only 変更のため、`dart analyze` と `flutter test` は実行しなかった。

## Context and Orientation

主要ファイル:

- `README.md`: project overview、setup、verification、maintenance policy。
- `QUICKSTART.md`: 短いセットアップとモデル取得手順。
- `CONTRIBUTING.md`: Issue / PR workflow と公開安全性ルール。
- `.github/workflows/flutter-ci.yml`: `flutter pub get`、`dart analyze`、`flutter test` を実行する CI。
- `.github/ISSUE_TEMPLATE/`: bug / feature report の構造化テンプレート。
- `docs/plans/plans.md`: 重要な計画決定の append-only log。
- `docs/plans/implementation_summary.md`: 実装結果と検証記録。
- `docs/plans/open_questions.md`: 未決事項、確認待ち、blocker。
- `docs/plans/project_checklist.md`: 完了済みチェックと公開整備の追跡候補。

制約:

- 個人写真、識別可能な人物画像、EXIF 付き画像、秘密情報、API key、token、ONNX model binaries は公開対象にしない。
- モデル本体、画像、大容量ファイル、依存追加、license 変更は原則避ける。Dependabot / Renovate の検討は設定追加のみに限定し、依存更新そのものは別途確認する。
- 利用実績、採用状況、外部評価は誇張しない。
- プロダクトの実装・保守・公開安全性に直接関係しない外部制度情報は docs に残さず、product / security / maintenance の一般論へ丸める。
- 変更ごとに最小検証を行い、実施コマンドと結果を `docs/plans/implementation_summary.md` に記録する。

## Plan of Work

### Day 1: `SECURITY.md`

- 目的: 脆弱性、秘密情報、個人画像、EXIF、モデル本体に関する報告方針を GitHub 標準の場所に置く。
- 期待効果: public issue で詳細や添付を出さない安全な導線が明確になる。
- 想定作業: `SECURITY.md` を追加し、公開 issue に載せない情報、対象範囲、初期報告の書き方を記載する。
- リスク: 個人メールなど公開したくない連絡先を書かない。連絡先が未定なら GitHub issue で最小説明のみとする。
- 検証: GitHub 上の Security policy 表示、`rg -n "EXIF|secrets|model binaries|personal" SECURITY.md CONTRIBUTING.md`。
- 観点: 公開安全性、docs。
- チェックリスト:
  - [x] 公開しない情報のリストを `CONTRIBUTING.md` と揃えた。
  - [x] 悪用手順や秘密情報を issue に載せない方針を明記した。
  - [x] 報告先に個人情報を追加しないことを確認した。
  - [x] `implementation_summary.md` に追加理由と検証を記録した。

### Day 2: model provenance / `MODEL_LICENSES.md`

- 目的: DexiNed / PiDiNet の取得元、SHA256、生成物、再配布可否、PiDiNet 商用利用要確認を contributor-facing docs で明確化する。
- 期待効果: on-device AI image processing の再現性と公開安全性が伝わり、モデル本体を再配布しない方針への質問に答えやすくなる。
- 想定作業: `MODEL_LICENSES.md` を追加するか、README / QUICKSTART の model provenance section を表で整理する。
- リスク: license や商用利用可否を断定しすぎると不正確になる。PiDiNet は「追加確認が必要」として扱う。
- 検証: `rg -n "DexiNed|PiDiNet|SHA256|commercial|redistribution|モデル本体|再配布" README.md QUICKSTART.md MODEL_LICENSES.md`。
- 観点: 公開安全性、docs。
- チェックリスト:
  - [ ] DexiNed の取得スクリプト、生成先、SHA256、再配布方針を確認した。
  - [ ] PiDiNet の export script、生成先、checkpoint SHA256、商用利用要確認を確認した。
  - [ ] モデル本体を Git 管理せず再配布しない方針を明記した。
  - [ ] README / QUICKSTART から model provenance へ辿れる導線を作った。

### Day 3: ignored artifact safety scan

- 目的: ignored の `assets/models/*.onnx`、`.DS_Store`、`build/`、`coverage/`、古い sample asset 由来の build 内ファイル名を誤って Git に追加しない仕組みを強める。
- 期待効果: 公開事故は確認されていない状態を維持しつつ、将来の誤 add を減らせる。
- 想定作業: ローカル掃除手順、pre-commit 的な手動チェック、または CI の公開安全性チェック候補を docs / workflow 方針に追加する。
- リスク: ignored artifact の削除は環境依存であり、未承認の破壊的操作にしない。CI で過剰に fail させると保守負担が増える。
- 検証: `git ls-files --cached --others --exclude-standard` と Git 管理対象の artifact 名検索。
- 観点: 公開安全性、CI/tests、active maintenance。
- チェックリスト:
  - [ ] Git 管理対象に ONNX model binaries、`.DS_Store`、build output、coverage output がないことを確認した。
  - [ ] ignored artifact の存在を GitHub 公開対象と区別して記録した。
  - [ ] 誤 add 防止の手動チェックまたは CI 化候補を決めた。
  - [ ] 秘密情報や個人情報の具体値を記録しないことを確認した。

### Day 4: CI badge と Actions 導線

- 目的: CI/tests が維持されていることを README 冒頭で可視化する。
- 期待効果: 初見の reviewer が GitHub Actions の存在と成功状態へすぐ辿れる。
- 想定作業: `Flutter CI` badge と Actions link を README に追加する。
- リスク: workflow 名や branch がずれると badge が壊れる。
- 検証: README 表示、badge URL、`gh run list --repo jtheonion/seizani_app --limit 3`。
- 観点: CI/tests、docs、active maintenance。
- チェックリスト:
  - [ ] workflow 名 `Flutter CI` と branch `main` を確認した。
  - [ ] README に badge を追加した。
  - [ ] Actions link が public repo で開けることを確認した。
  - [ ] `docs/plans/implementation_summary.md` に検証結果を記録した。

### Day 5: network dependency / ChromaDB comment audit

- 目的: `pubspec.yaml` の `http` / `dio` と ChromaDB client コメントが、「ユーザー画像を外部送信しない」主張に対して不要な疑問を生まないようにする。
- 期待効果: privacy-conscious / on-device 方針との整合を説明しやすくなる。
- 想定作業: 依存の使用箇所を検索し、未使用なら削除候補、必要なら用途とユーザー画像を送信しない境界を README / docs に明記する。
- リスク: 依存削除はビルド影響があるため、実施する場合は `flutter pub get`、`dart analyze`、`flutter test` を必要に応じて行う。
- 検証: `rg -n "package:http|package:dio|http\\.|Dio\\(|ChromaDB|chroma" lib test pubspec.yaml`。
- 観点: 公開安全性、docs、CI/tests。
- チェックリスト:
  - [ ] `http` / `dio` の使用有無を確認した。
  - [ ] ChromaDB client コメントの必要性を確認した。
  - [ ] 未使用なら削除計画、必要なら用途説明を決めた。
  - [ ] 個人画像を外部送信しない主張との整合を確認した。

### Day 6: Dependabot / Renovate 導入方針

- 目的: 依存更新と vulnerability response の保守姿勢を示す入口を作る。
- 期待効果: active maintenance と security response の証拠になる。
- 想定作業: Dependabot か Renovate のどちらを使うか決め、Flutter / GitHub Actions の更新監視を小さく設定する。
- リスク: 自動 PR が多すぎると保守負荷になる。初期設定は低頻度・限定対象にする。
- 検証: YAML / JSON 構文確認、GitHub 上の dependency graph / alerts 設定確認。
- 観点: dependency maintenance、公開安全性、active maintenance。
- チェックリスト:
  - [ ] Dependabot と Renovate のどちらを使うか決めた。
  - [ ] 対象 ecosystem と頻度を最小化した。
  - [ ] dependency update PR の扱いを `CONTRIBUTING.md` または docs に書くか判断した。
  - [ ] 設定ファイルの構文を確認した。

### Day 7: Issue template config

- 目的: blank issue の扱いと安全な報告導線を明確にする。
- 期待効果: 個人画像、EXIF、秘密情報、モデル本体が issue に添付されるリスクをさらに下げる。
- 想定作業: `.github/ISSUE_TEMPLATE/config.yml` を追加し、template 利用を促す。
- リスク: blank issue を完全に閉じると、想定外の報告がしにくくなる。必要なら開いたまま注意書きを強める。
- 検証: YAML parse、GitHub New issue 画面確認。
- 観点: 公開安全性、active maintenance。
- チェックリスト:
  - [ ] blank issue を許可するか無効にするかを決めた。
  - [ ] security / privacy 注意文と既存 template の文言が矛盾しないことを確認した。
  - [ ] YAML 構文確認を行った。
  - [ ] `implementation_summary.md` に検証結果を記録した。

### Day 8: contributor-facing docs 前面化

- 目的: contributor-facing docs と内部運用ログの見え方を整理する。
- 期待効果: 初見の contributor / reviewer が README、CONTRIBUTING、SECURITY、MODEL_LICENSES から必要情報に辿りやすくなる。
- 想定作業: README の Documentation section を contributor-facing docs 優先に整理し、内部運用ログは必要な人向けの位置づけにする。
- リスク: 既存の canonical docs 運用を隠しすぎると、この repo の保守記録の強みが弱くなる。前面化と削除は分けて考える。
- 検証: README / CONTRIBUTING から public-facing docs へ辿れること、内部 docs の説明が過剰でないことを確認する。
- 観点: docs、active maintenance。
- チェックリスト:
  - [ ] README の docs 導線を contributor 目線で確認した。
  - [ ] SECURITY / MODEL_LICENSES / CONTRIBUTING を前面に出すか判断した。
  - [ ] 内部運用ログを削除せず、位置づけだけ整理した。
  - [ ] README の説明が実績の誇張に見えないことを確認した。

### Day 9: CHANGELOG / release 導線

- 目的: 継続保守と変更履歴を contributor-facing に見える形で残す。
- 期待効果: active maintenance の証拠が implementation log だけに閉じず、一般的な OSS の導線になる。
- 想定作業: `CHANGELOG.md` を追加するか、README に release notes 方針を短く追加する。
- リスク: 過去履歴を細かく掘り起こすと時間がかかる。初回は `Unreleased` と公開整備以降の小改善だけでよい。
- 検証: `rg -n "CHANGELOG|Unreleased|release" README.md CHANGELOG.md docs/plans/implementation_summary.md`。
- 観点: docs、active maintenance。
- チェックリスト:
  - [ ] 初回 CHANGELOG の粒度を決めた。
  - [ ] 未リリース変更と公開整備済み変更を分けた。
  - [ ] README から changelog へ辿れるか確認した。
  - [ ] implementation log と changelog の役割を混同しないことを確認した。

### Day 10: canonical docs の鮮度更新

- 目的: 公開整備後の状態を `project_checklist.md`、`open_questions.md`、`plans.md` に反映する。
- 期待効果: docs が 5 月時点で止まって見える問題を減らす。
- 想定作業: 公開整備、CI、Issue template、security policy、モデル方針のチェック項目を追加または整理する。
- リスク: 未実施の項目を完了済みにしない。
- 検証: `rg -n "OSS|CI|Issue|Security|公開|モデル" docs/plans/project_checklist.md docs/plans/open_questions.md docs/plans/plans.md`。
- 観点: docs、active maintenance。
- チェックリスト:
  - [ ] 完了済みと未完了を分けて記録した。
  - [ ] `open_questions.md` に未決事項だけを残した。
  - [ ] `plans.md` は append-only を維持した。
  - [ ] `implementation_summary.md` に docs 同期結果を記録した。

### Day 11: maintenance snapshot

- 目的: repo 状態を定期点検している証拠を残す。
- 期待効果: active maintenance と public-safety maintenance の時系列記録になる。
- 想定作業: Git 状態、CI、Issue、公開対象ファイル名、秘密情報パターンの軽量確認を行い、結果を記録する。
- リスク: GitHub CLI が network / auth で失敗する可能性がある。失敗時はローカル確認のみを明記する。
- 検証: `git status --short --branch`、`gh run list`、`gh issue list`、`git ls-files` + `rg`。
- 観点: active maintenance、公開安全性、CI/tests。
- チェックリスト:
  - [ ] `main` と `origin/main` の状態を確認した。
  - [ ] 直近 CI run の status / conclusion を確認した。
  - [ ] open issue の有無を確認した。
  - [ ] Git 管理対象に `.env`、key、certificate、ONNX model binaries、`.DS_Store` がないことを確認した。
  - [ ] adoption signal は誇張せず、early-stage として記録した。
  - [ ] 結果を `implementation_summary.md` に記録した。

### Day 12: PiDiNet smoke test

- 目的: PiDiNet 線画から星座化、保存 / 共有対象生成までの手動確認を行う。
- 期待効果: unit test だけでは見えないユーザー体験と端末依存のリスクを確認できる。
- 想定作業: Simulator または web-server で起動し、公開サンプルまたは合成入力で操作を確認する。
- リスク: ローカルモデルや simulator 状態に依存する。モデルがない場合は blocker として記録する。
- 検証: `flutter run -d <device-id>` または `flutter run -d web-server`、操作結果の記録。
- 観点: ユーザー体験、CI/tests、active maintenance。
- チェックリスト:
  - [ ] 使用した device / runtime を記録した。
  - [ ] モデル有無と取得 / 生成状態を記録した。
  - [ ] `PiDiNet線画 -> 星座に変換 -> 保存/共有対象生成` を確認した。
  - [ ] 失敗した場合は再現手順と blocker を `open_questions.md` または `implementation_summary.md` に記録した。

### Day 13: settings TODO 整理

- 目的: 未実装 settings button の操作時挙動を明確にする。
- 期待効果: ユーザーが押しても無反応に見える UI を減らす。
- 想定作業: button を一時非表示、disabled、または最小 snackbar にする。選択は既存 UI 方針に合わせる。
- リスク: UI 変更により widget test や screenshot 期待がずれる可能性がある。
- 検証: `flutter test test/widget_test.dart`、必要なら関連 widget test。
- 観点: ユーザー体験、tests。
- チェックリスト:
  - [ ] settings の短期方針を決めた。
  - [ ] 変更を最小 UI 差分にした。
  - [ ] widget test を実行した。
  - [ ] user-facing text が過剰説明になっていないことを確認した。

### Day 14: analyzer info 指摘の棚卸し

- 目的: `dart analyze` は exit 0 でも info 指摘が残っているため、1 カテゴリだけ改善または計画化する。
- 期待効果: code quality maintenance の継続証拠になる。
- 想定作業: `unnecessary_import` など低リスクカテゴリを 1 つ選び、件数確認と小修正を行う。
- リスク: 広範囲に触ると差分が大きくなる。1 カテゴリ、少数ファイルに限定する。
- 検証: `dart analyze`、対象 test。
- 観点: CI/tests、active maintenance。
- チェックリスト:
  - [ ] info 指摘のカテゴリと件数を確認した。
  - [ ] 低リスクな対象だけを選んだ。
  - [ ] `dart analyze` を再実行した。
  - [ ] 改善できない指摘は理由を記録した。

### Day 15: 月次 maintenance routine

- 目的: 今後の定期確認手順を docs に固定する。
- 期待効果: 保守を続ける前提が、再現可能な運用として残る。
- 想定作業: 月次で確認するコマンド、公開安全性スキャン、CI 確認、モデル方針確認、docs 同期を短く記載する。
- リスク: 手順を増やしすぎると実行されなくなる。15〜30 分で回せる粒度にする。
- 検証: 手順内コマンドの dry-run または現状確認。
- 観点: active maintenance、docs、公開安全性、CI/tests。
- チェックリスト:
  - [ ] 月次確認の目的を明記した。
  - [ ] 実行コマンドを 5〜8 個以内に絞った。
  - [ ] 記録先を `implementation_summary.md` に固定した。
  - [ ] 次回以降の未決事項は `open_questions.md` に分ける方針を明記した。

## Concrete Steps

各日の開始時:

1. `git status --short --branch` で開始状態を確認する。
2. 対象ファイルを読む。
3. 変更範囲が 60 分以内に収まるか確認する。
4. 大容量ファイル、モデル本体、個人情報、秘密情報、license 変更、依存追加を含まないことを確認する。

各日の作業中:

1. 変更は最小差分にする。
2. 仕様判断が出た場合は `plans.md` または実行中 ExecPlan に追記する。
3. 未決事項や確認待ちは `open_questions.md` に分離する。
4. プロダクトの実装・保守・公開安全性に直接関係しない外部制度情報は記録しない。

各日の完了時:

1. 変更領域に対応する最小検証を実行する。
2. `git diff --check` を実行する。
3. `docs/plans/implementation_summary.md` に実施内容、検証コマンド、結果、残課題を記録する。
4. 必要に応じて `plans.md`、`project_checklist.md`、`open_questions.md` を同期する。
5. 最終報告で「ドキュメント更新済み: はい／いいえ」を明記する。

## Validation and Acceptance

全体受け入れ条件:

- [ ] 15 件の改善がすべて 15〜60 分程度の低リスク作業として実施可能である。
- [ ] 各改善に目的、期待効果、想定作業、リスク、検証方法がある。
- [ ] 各改善が active maintenance、公開安全性、docs、CI/tests、dependency maintenance、ユーザー体験のいずれに効くか明示されている。
- [ ] 大規模機能追加、依存追加、license 変更、モデル本体追加、大容量ファイル追加を避けている。
- [ ] 各日の完了時に `implementation_summary.md` へ検証結果が記録される。
- [ ] プロダクトの実装・保守・公開安全性に直接関係しない外部制度情報が記録されていない。

この計画書自体の検証:

- [ ] `rg -n "Day 1|Day 15|Validation and Acceptance|Idempotence" docs/plans/execplans/daily_low_risk_oss_maintenance_plan.md`
- [ ] `rg -n "プロダクトの実装・保守・公開安全性に直接関係しない外部制度" .agent/DOCS.md docs/plans/execplans/daily_low_risk_oss_maintenance_plan.md`
- [ ] `git diff --check`
- [ ] `git status --short --branch`

## Idempotence and Recovery

- docs-only の日次改善は、失敗した場合も partial diff を確認して中断できる。
- GitHub CLI が network / auth で失敗した場合は、ローカルで確認できた範囲と失敗理由を記録し、外部状態確認を翌日に回す。
- Flutter / Dart command が SDK cache 権限で失敗した場合は、失敗内容を記録し、必要に応じて承認付きで再実行する。
- モデル取得 / 生成が必要な作業は、モデル本体を Git に追加しない。失敗時は blocker として `open_questions.md` に残す。
- Dependabot / Renovate 設定で大量 PR や不要な依存更新が起きる場合は、対象 ecosystem や頻度を縮小する。
- 意図しないファイルや ignored artifact が出た場合は、Git 管理対象かどうかを確認してから扱う。未承認の破壊的操作はしない。

## Artifacts and Notes

- この計画書: `docs/plans/execplans/daily_low_risk_oss_maintenance_plan.md`
- 重要決定の同期先: `docs/plans/plans.md`
- 実施記録の同期先: `docs/plans/implementation_summary.md`
- 未決事項の同期先: `docs/plans/open_questions.md`

やらないこと:

- 採用実績、stars、forks、downloads を誇張する。
- adoption signal の弱さを隠すために空 issue、見せかけ PR、外部投稿を作る。
- 見せかけの issue / PR / commit を作る。
- モデル本体、個人画像、EXIF 付き画像、秘密情報、大容量ファイルを追加する。
- license 変更や依存追加を軽作業として扱う。
- プロダクトの実装・保守・公開安全性に直接関係しない外部制度情報を docs に残す。

## Interfaces and Dependencies

- Flutter SDK: `flutter pub get`、`dart analyze`、`flutter test`、必要時 `flutter run`。
- GitHub Actions: `.github/workflows/flutter-ci.yml`。
- GitHub CLI: `gh repo view`、`gh run list`、`gh issue list`。network / auth に依存する。
- Model tools: `tool/fetch_dexined_model.dart`、`tool/export_pidinet_onnx.py`。モデル本体は Git 管理対象外。
- Repo-local docs policy: `.agent/DOCS.md`、`.agent/PLANS.md`、`AGENTS.md`。
*** End Patch
