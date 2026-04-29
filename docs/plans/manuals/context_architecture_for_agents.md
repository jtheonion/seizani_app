# Context Architecture For Agents

## 目的
- repository-level context を最小化し、必要時だけ詳細を読む構造にする。
- 情報過積載を避けつつ、agent が判断に必要な参照関係へ到達できるようにする。

## 現在の実装境界
- L1 は `AGENTS.md`
- L2 は `.agent/DOCS.md`, `.agent/PLANS.md`, `.agent/modules/*`
- L3 は `docs/plans/manuals/*`, `docs/plans/blueprints/*`, `docs/plans/execplans/*`, `docs/plans/archive/execplans/*`, `docs/plans/*.md`, `work/memory/*`

## L1 / L2 / L3
1. L1: root router
   - `AGENTS.md` は必須制約と参照先だけを書く。
2. L2: policy and module instructions
   - `.agent/DOCS.md` は doc policy
   - `.agent/PLANS.md` は ExecPlan policy
   - `.agent/modules/requirements.md`
   - `.agent/modules/planning.md`
   - `.agent/modules/implementation.md`
   - `.agent/modules/verification.md`
   - `.agent/modules/memory.md`
3. L3: task-relevant data
   - manual、blueprint、append-only JSONL を必要時だけ読む。

## Root に書いてよいもの
- non-discoverable な必須制約
- どの policy / module / manual を読むべきかの routing
- 実装完了前に必要な最小検証と記録の要求

## Root に書かないもの
- discoverable なディレクトリ説明
- template placeholder
- module ごとの詳細 workflow
- 全 data schema の全文

## Module Layer
- `.agent/modules/requirements.md`
  - requirements closure、open questions 分離、question batch、blocker 判定
- `planning.md`
  - ExecPlan を正本にする進め方、再計画条件、planning manual への導線
- `implementation.md`
  - 最小差分、役割境界、文書同期、scope 制御
- `verification.md`
  - affected-area 検証、`tests / logs / diff`、実装記録の残し方
- `memory.md`
  - append-only JSONL、`archived`、cross-reference、lookup chain

## Data Layer
- `docs/plans/plans.md`
  - 重要な判断を残す append-only の canonical plan log
- `docs/plans/requirements.md`
  - 確定済み要件本体と変更履歴の canonical requirements
- `docs/plans/open_questions.md`
  - 未決事項、確認待ち、推奨デフォルト、blocker 判定
- `docs/plans/implementation_summary.md`
  - 実装結果、検証コマンドと結果、整合回復の記録
- `docs/plans/bestpractice/lessons.md`
  - recurring failure や user correction から抽出した generalized rule
- `work/memory/decisions.jsonl`
  - repo-level の判断、採用理由、代替案、結果
- `work/memory/experiences.jsonl`
  - notable outcome や観測
- `work/memory/failures.jsonl`
  - root cause と prevention

## Cross-Reference
- `source_doc`
  - manual / execplan / requirements へ戻るための必須キー
- `related_decision_id`
  - experience / failure を判断記録へ結びつける

## Lookup Chains
- requirements lookup:
  - `AGENTS.md` -> `.agent/DOCS.md` -> `.agent/modules/requirements.md` -> `docs/plans/open_questions.md` -> `docs/plans/manuals/requirements_closure_workflow.md`
- planning lookup:
  - `AGENTS.md` -> `.agent/PLANS.md` -> `.agent/modules/planning.md` -> `docs/plans/manuals/planning_annotation_workflow.md`
- verification lookup:
  - `AGENTS.md` -> `.agent/modules/verification.md` -> `docs/plans/implementation_summary.md`
- plan log lookup:
  - `AGENTS.md` -> `.agent/DOCS.md` -> `docs/plans/plans.md`
- failure lookup:
  - `.agent/modules/memory.md` -> `work/memory/failures.jsonl` -> `source_doc` / `related_decision_id`
- architecture lookup:
  - `AGENTS.md` -> `docs/plans/manuals/context_architecture_for_agents.md` -> `.agent/DOCS.md`

## Skills の分離
- reference skill
  - 自動ロード前提。継続的一貫性を担保する。
- task skill
  - 明示起動前提。workflow と quality gate を強く固定する。

## 評価観点
- success rate だけで見ない。
- steps、cost、first relevant file 到達、reasoning tokens、tool bias を確認する。
- four-arm evaluation は別フェーズとし、今回の実装では構造変更だけを先行する。

## Related References
- Policy:
  - `.agent/DOCS.md`
  - `.agent/PLANS.md`
- Manual:
  - `docs/plans/manual.md`
  - `docs/plans/manuals/planning_annotation_workflow.md`
- Blueprint:
  - `docs/plans/blueprints/single_plan_orchestration_blueprint.md`
