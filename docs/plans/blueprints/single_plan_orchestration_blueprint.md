# ExecPlan Blueprint: Single-Plan Orchestration

## Purpose / Big Picture
- 単発依頼を `requirements closure -> plan -> investigate -> implement -> verify -> repair -> completion` の 1 本の流れで扱うための汎用 blueprint。
- 会話履歴ではなく Markdown の ExecPlan を正本にし、main agent、subagent、background agent、session rollover を同じ状態機械で扱う。
- repo-local の文書だけで再利用できるようにし、repo 外の install や固有環境には依存しない。

## Progress
- [ ] 依頼入力の正規化
- [ ] requirements closure 完了
- [ ] plan freeze 完了
- [ ] implementation / verification 完了
- [ ] 記録と docs 同期完了

## Surprises & Discoveries
- 実行中に見つかった制約、前提抜け、予想外の依存を追記する。
- plan を分割すべき兆候や、1 本で維持できる理由を残す。

## Outcomes & Retrospective
- 完了後に、単一計画書で管理して有効だった点と不足した点をまとめる。
- 再利用できる運用ルールがあれば `docs/plans/bestpractice/lessons.md` へ還元する。

## Decision Log
- D1: 非 trivial な単発依頼は 1 本の ExecPlan を正本にする。
- D2: `requirements.md` には確定事項のみ、未決事項は `open_questions.md` に分離する。
- D3: `red` signal の未解決事項や approval 必須項目が残る場合は実装しない。
- D4: main agent が plan 更新、整合確認、最終判断、完了判定を担当する。
- D5: subagent / background agent は read-heavy task を中心に使い、shared write surface の ownership は持たせない。

## Context and Orientation
- Root:
  - `AGENTS.md`
- Policy / Module:
  - `.agent/PLANS.md`
  - `.agent/modules/requirements.md`
  - `.agent/modules/planning.md`
  - `.agent/modules/implementation.md`
  - `.agent/modules/verification.md`
- Manual:
  - `docs/plans/manuals/requirements_closure_workflow.md`
  - `docs/plans/manuals/planning_annotation_workflow.md`
  - `docs/plans/manuals/background_agent_operations.md`
  - `docs/plans/manuals/context_architecture_for_agents.md`
- Canonical Records:
  - `docs/plans/requirements.md`
  - `docs/plans/open_questions.md`
  - `docs/plans/plans.md`
  - `docs/plans/implementation_summary.md`

## Active State Fields
- `Requirements Status`
  - `draft` / `clarification_needed` / `approved_for_planning` / `approved_for_implementation`
- `Open Questions Ref`
  - 通常は `docs/plans/open_questions.md`
- `Current Goal`
- `Success Criteria`
- `Constraints`
- `Out of Scope`
- `Active Milestone`
- `Delegation Map`
- `Verification Gate`
- `Next Action`
- `Approval Needed`
- `Assumption Budget`

## Operating Loop
1. Intake
- 依頼から Goal、Deliverables、Success Criteria、Constraints、Out of Scope を抽出し、この plan に固定する。
2. Requirements Closure
- 確定要件を `docs/plans/requirements.md`、未決事項を `docs/plans/open_questions.md` に分離する。
- clarification は 3-7 件の high-value question batch にまとめる。
3. Plan Freeze
- milestone、acceptance、verification command、rollback、delegation 候補を plan に固定する。
4. Delegation
- 調査、比較、ログ要約、失敗分類は subagent や background agent に切り出す。
5. Milestone Loop
- implement -> verify -> repair -> state update を milestone 単位で閉じる。
6. Session Control
- `/compact`、`/resume`、`/fork` を使う前に `Next Action` と blocker を plan に残す。
7. Completion
- `implementation_summary.md`、`plans.md`、`open_questions.md` を同期し、未解決事項を明示して完了する。

## Delegation Rules
- main agent ownership:
  - canonical plan 更新
  - public-facing summary
  - 最終判断
  - 完了判定
- subagent allowed:
  - read-heavy 調査
  - ログ要約
  - 失敗分類
  - 候補比較
- subagent prohibited:
  - canonical plan の ownership
  - shared write surface の並列編集
  - 完了判定の単独実施
- background agent allowed:
  - report-only deep research
  - triage
  - 翌日レビュー前提の素材集め
- background agent prohibited:
  - merge
  - 外部返信
  - 本番変更

## Session Rollover Rules
- rollover 前に `Active Milestone`、`Verification Gate`、`Next Action`、未解決 blocker を plan に明記する。
- `/compact` は milestone 中でも許可するが、次の一手を plan に残してから実施する。
- `/resume` は会話要約より先に ExecPlan を読む。
- `/fork` は比較検討用に使い、不採用案は `Decision Log` へ戻す。

## Plan of Work
1. 依頼入力を plan の状態項目へ正規化する。
2. requirements closure を完了する。
3. milestone と verification gate を upfront で固定する。
4. 必要に応じて delegation を使いながら main plan を維持する。
5. implement / verify / repair を milestone ごとに閉じる。
6. append-only 記録と docs 同期を行って完了する。

## Concrete Steps
1. `Requirements Status`、`Current Goal`、`Success Criteria`、`Constraints`、`Out of Scope` を記入する。
2. `docs/plans/requirements.md` と `docs/plans/open_questions.md` を初期化する。
3. `red` signal の blocker があれば question batch を出し、回答待ちで止める。
4. `Active Milestone`、`Delegation Map`、`Verification Gate`、`Next Action` を初期化する。
5. 実装と検証を進め、milestone ごとに状態を更新する。
6. `implementation_summary.md`、`plans.md`、`open_questions.md` を同期して閉じる。

## Embedded Skill Contract
- Name:
  - `single-plan-orchestrator` 相当
- Input:
  - user request
  - success criteria
  - constraints
  - optional references
- Required Reads:
  - `AGENTS.md`
  - `.agent/PLANS.md`
  - `.agent/modules/planning.md`
  - relevant manual
  - 本 blueprint を複製した ExecPlan
- Output:
  - requirements closure summary
  - question batch
  - initialized ExecPlan
  - milestone updates
  - delegation summary
  - verification result
  - completion summary
- Guardrails:
  - 会話ではなく plan を正本にする
  - 未決事項を requirements 本体へ混ぜない
  - `red` signal 未解決のまま実装しない
  - verification なしで完了しない

## Validation and Acceptance
- 受け入れ条件:
  - requirements closure と open question 管理が plan に組み込まれている。
  - 単発依頼から completion までの状態遷移が 1 本の plan に収まっている。
  - subagent / background agent / session rollover の条件が plan に明記されている。
  - `AGENTS.md`、manual、module からこの blueprint に到達できる。
- 検証例:
  - `test -f docs/plans/blueprints/single_plan_orchestration_blueprint.md`
  - `rg -n "single_plan_orchestration_blueprint|Open Questions Ref|Approval Needed|Assumption Budget" AGENTS.md .agent docs/plans`
  - `rg -n "open_questions\\.md|requirements_closure_workflow" .agent docs/plans README.md`

## Idempotence and Recovery
- 文書変更は追記または参照追加を基本とし、再実行しても同じ routing と state に収束する。
- 単一 plan が過剰と判明した場合は、理由を `Decision Log` に残して別 plan へ分割する。
- 追加ツールや外部 skill が必要になった場合は、別 plan で扱う。

## Artifacts and Notes
- Blueprint:
  - `docs/plans/blueprints/single_plan_orchestration_blueprint.md`
- Connected Docs:
  - `AGENTS.md`
  - `.agent/modules/requirements.md`
  - `.agent/modules/planning.md`
  - `docs/plans/manual.md`
  - `docs/plans/manuals/requirements_closure_workflow.md`
  - `docs/plans/manuals/planning_annotation_workflow.md`
  - `docs/plans/manuals/background_agent_operations.md`
- Records:
  - `docs/plans/plans.md`
  - `docs/plans/open_questions.md`
  - `docs/plans/implementation_summary.md`

## Interfaces and Dependencies
- 依存:
  - root / module / manual の routing
  - requirements closure と question batch 運用
  - append-only 記録ルール
  - subagent と background agent の既存運用
- interface change:
  - 新しいコード API は追加しない。
  - 運用インターフェースとして「単一 plan を正本にする」契約を追加する。

## Related References
- Manual:
  - `docs/plans/manual.md`
  - `docs/plans/manuals/requirements_closure_workflow.md`
  - `docs/plans/manuals/planning_annotation_workflow.md`
  - `docs/plans/manuals/background_agent_operations.md`
  - `docs/plans/manuals/context_architecture_for_agents.md`
- Companion Blueprint:
  - `docs/plans/blueprints/requirements_closure_gate_blueprint.md`
