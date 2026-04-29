# Documentation Policy

## Priority
1. `.agent/DOCS.md`
2. `.agent/PLANS.md`
3. `AGENTS.md`

## Canonical Documents
- `docs/plans/plans.md`
  - append-only の計画ログ。重要な決定はここに追記する。
- `docs/plans/requirements.md`
  - 確定済み要件本体 + append-only の変更履歴を維持する。
- `docs/plans/open_questions.md`
  - 未決事項、確認待ち、推奨デフォルト、blocker 判定の正本。
- `docs/plans/implementation_summary.md`
  - 実装結果、追加/更新ファイル、検証コマンドと結果の正本。
- `docs/plans/bestpractice/lessons.md`
  - user correction や recurring failure から抽出した generalized rule の append-only 正本。
- `docs/plans/manual.md`
  - manual の入口。workflow 固有の詳細手順は manual 側へ置く。

## Update Rules
- 文書は加算更新を優先する。
- この repo でいう「自動反映」は、エージェントが変更内容に応じて canonical documents だけを選び、repo-local rule に従って更新する運用を指す。
- 重要な決定は `docs/plans/plans.md` と実行中の ExecPlan に残す。
- 実装完了時は `docs/plans/implementation_summary.md` を更新する。
- 反映対象は canonical documents に限定し、変更内容に応じて `plans.md`、`requirements.md`、`open_questions.md`、`implementation_summary.md`、必要時 `bestpractice/lessons.md` を更新する。
- incident の具体記録は `work/memory/failures.jsonl`、再利用可能な rule は `docs/plans/bestpractice/lessons.md` に分ける。
- `plans.md` は append-only を維持する。
- `requirements.md` は最新版セクションと変更履歴の 2 層構成を崩さず、確定事項のみを置く。
- 未決事項、確認待ち、推奨デフォルト、blocker 判定は `open_questions.md` へ分離する。
- discoverable な説明やディレクトリ一覧は root 文書へ重ね書きしない。

## Routing
- requirements / planning / implementation / verification / memory の詳細は `.agent/modules/*` を参照する。
- context 構造の考え方は `docs/plans/manuals/context_architecture_for_agents.md` を参照する。
- 背景運用は `docs/plans/manuals/background_agent_operations.md`、計画注釈は `docs/plans/manuals/planning_annotation_workflow.md`、要件確定は `docs/plans/manuals/requirements_closure_workflow.md` を参照する。
- blueprint は `docs/plans/blueprints/`、完了済み ExecPlan は `docs/plans/archive/execplans/` を参照する。
