# manual.md
- 最終更新日: 2026-04-30
- バージョン: 0.1

## 目的
- `docs/plans/manuals/` 配下の運用マニュアルへの入口を一元化する。
- source-backed な運用手順を、計画書とは分離して参照できる状態を維持する。

## マニュアル一覧
1. `docs/plans/manuals/planning_annotation_workflow.md`
   - 深掘り調査、計画注釈、再計画、完了前検証の手順。
2. `docs/plans/manuals/background_agent_operations.md`
   - EOD agent、slam dunk 委譲、通知制御、harness engineering の手順。
3. `docs/plans/manuals/context_architecture_for_agents.md`
   - L1/L2/L3、minimal root、`.agent/modules/*`、`work/memory/*`、cross-reference の設計原則。
4. `docs/plans/manuals/requirements_closure_workflow.md`
   - open questions 分離、質問 batch、signal 別の停止条件、requirements closure の手順。

## 使い分け
- 非 trivial 作業の進め方を確認したいときは `planning_annotation_workflow.md` を読む。
- 日次運用や背景エージェント委譲を整理したいときは `background_agent_operations.md` を読む。
- AGENTS / skill / JSONL 構造を設計するときは `context_architecture_for_agents.md` を読む。
- 単一プロンプトの依頼で未決事項を整理したいときは `requirements_closure_workflow.md` を読む。
- 単発依頼を 1 回の流れで完走する運用設計を確認したいときは `docs/plans/blueprints/single_plan_orchestration_blueprint.md` を読む。

## Related References
- 進行中 ExecPlan ディレクトリ: `docs/plans/execplans/`
- 完了済み ExecPlan ディレクトリ: `docs/plans/archive/execplans/`
- blueprint ディレクトリ: `docs/plans/blueprints/`
- 単一計画書のひな形: `docs/plans/blueprints/single_plan_orchestration_blueprint.md`
- requirements closure のひな形: `docs/plans/blueprints/requirements_closure_gate_blueprint.md`
