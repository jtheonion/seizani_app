# ExecPlan Policy

## Storage
- 進行中 ExecPlan: `docs/plans/execplans/`
- blueprint: `docs/plans/blueprints/`
- 完了済み ExecPlan: `docs/plans/archive/execplans/`

## ExecPlan Required When
- 複数ファイルにまたがる変更
- 影響範囲が広い仕様変更
- 手順が多段で進捗記録が必要
- 受け入れ条件の検証が複数必要

## Required Sections
- Purpose / Big Picture
- Progress
- Surprises & Discoveries
- Decision Log
- Outcomes & Retrospective
- Context and Orientation
- Plan of Work
- Concrete Steps
- Validation and Acceptance
- Idempotence and Recovery
- Artifacts and Notes
- Interfaces and Dependencies

## Operating Rules
- 3 ステップ以上または設計判断がある作業では plan mode を必須とする。
- plan mode 開始時に requirements closure を確認し、未決事項は `docs/plans/open_questions.md` へ隔離する。
- verification も同じ plan の一部として扱う。
- plan には detailed spec と checkable todo を upfront で固定する。
- clarification は 1 件ずつ増やさず、高価値な 3-7 件の質問 batch を優先する。
- `red` signal の open question が未解決、または approval 必須項目が未承認なら実装へ進まない。
- 想定外が出たら実装継続より停止・再計画を優先する。
- ExecPlan は生きている文書として更新する。
- 進捗は停止ポイントごとに更新する。
- 検証可能な受け入れ条件を必ず記述する。
- 不確実点を残さず、実装者が判断不要な粒度まで具体化する。
- 重要な設計判断や batch 単位の結論は `docs/plans/plans.md` にも追記する。

## Boundary
- `AGENTS.md` は L1 router として必須制約と参照先だけを持つ。
- `.agent/PLANS.md` は ExecPlan の policy/index を持つ。
- workflow-heavy な手順は `.agent/modules/planning.md` と manuals に置く。
- discoverable な説明や directory inventory は root へ戻さない。

## Routing
- Requirements workflow: `.agent/modules/requirements.md`
- Planning workflow: `.agent/modules/planning.md`
- Verification workflow: `.agent/modules/verification.md`
- Best practice lessons: `docs/plans/bestpractice/lessons.md`
- Context architecture: `docs/plans/manuals/context_architecture_for_agents.md`
