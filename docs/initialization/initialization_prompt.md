以下を順序厳守で実行してください。目的は、AGENTS運用を開始できる初期状態を完成させることです。

前提:
- `PROJECT_ROOT` は「この依頼を実行しているワークスペースのルート」。
- ルート判定は `git rev-parse --show-toplevel` を優先し、失敗時はカレントディレクトリを `PROJECT_ROOT` とする。
- 以降の全パスは `PROJECT_ROOT` 基準で扱う。

実行ルール:
- 返答言語は日本語
- 破壊的操作は禁止
- `PROJECT_ROOT` 外の変更は禁止
- `plans.md` は append-only 厳守
- `requirements.md` は「要件本体（最新版）」+「変更履歴（append-only）」の2層構成を厳守
- 未決事項は `open_questions.md` に分離し、requirements 本体へ混ぜない
- 初期化の完了を妨げない将来検討事項や運用改善案は `open_questions.md` に入れず、既定値を採用して `requirements.md` / `plans.md` に記録する

実行手順:
1. 読み取り確認（変更なし）
- `${PROJECT_ROOT}/AGENTS.md`
- `${PROJECT_ROOT}/.agent/DOCS.md`
- `${PROJECT_ROOT}/.agent/PLANS.md`
- `${PROJECT_ROOT}/README.md`
- `${PROJECT_ROOT}/docs/initialization/codex_home_prerequisites.md`
を読み、矛盾点と未置換プレースホルダを列挙する。

2. 初期要件を先に確定（先行実施）
- `${PROJECT_ROOT}/docs/plans/requirements.md`
に初期要件（機能/非機能/制約）を具体記入する。
- 同ファイルの変更履歴（append-only）に今回の追加内容を追記する。

3. 未決事項を分離して初期化
- `${PROJECT_ROOT}/docs/plans/open_questions.md`
に、要件確定時点で残った未決事項、質問 batch、推奨デフォルト、blocker を記録する。
- 初期化自体に不要な将来検討事項は記録対象外とし、既定値で閉じる。

4. 初回計画ログを追記（要件確定後）
- `${PROJECT_ROOT}/docs/plans/plans.md`
に、手順2-3で整理した要件と未決事項に整合する初回計画ログを append-only で追記する。

5. 初期チェックリストを実態反映
- `${PROJECT_ROOT}/docs/plans/project_checklist.md`
の初期チェック項目を、手順1〜4の実施結果に合わせて更新する。

6. 必須構成の存在検証
- `${PROJECT_ROOT}/docs/plans/`
- `${PROJECT_ROOT}/work/`
が揃っているか確認する。

7. 実施ログ記録と最終報告
- 検証コマンドと結果を
`${PROJECT_ROOT}/docs/plans/implementation_summary.md`
に記録する。
- 最終報告は「実施内容」「検証結果」「未決事項」を簡潔にまとめ、
「ドキュメント更新済み: はい／いいえ」を明記する。
