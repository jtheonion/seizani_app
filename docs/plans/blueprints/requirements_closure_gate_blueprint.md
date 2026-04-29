# ExecPlan Blueprint: Requirements Closure Gate

## Purpose / Big Picture
- 単一プロンプト運用で不足しやすい要件を、実装前に検知して整理するための companion blueprint。
- 確定要件は `requirements.md`、未決事項は `open_questions.md` に分離し、質問回数ではなく question batch で前進する。
- `red` signal の blocker が残る間は、planning や implementation へ進ませない。

## Progress
- [ ] 依頼から確定事項を抽出した
- [ ] `requirements.md` を更新した
- [ ] `open_questions.md` を初期化した
- [ ] question batch を確定した
- [ ] plan 側の blocker 状態を同期した

## Surprises & Discoveries
- 依頼文だけでは確定しない条件、危険な仮定、承認待ち項目を追記する。

## Outcomes & Retrospective
- requirements closure の結果、どこまで確定し何が blocker として残ったかを要約する。
- 今後の starter 改善に使える学びがあれば lesson として昇格する。

## Decision Log
- D1: `requirements.md` には確定事項のみを書く。
- D2: 未決事項は `docs/plans/open_questions.md` を正本にする。
- D3: clarification は 3-7 件の high-value batch に束ねる。
- D4: `red` signal や approval 必須項目が残る場合は実装しない。

## Context and Orientation
- Root:
  - `AGENTS.md`
- Policy / Module:
  - `.agent/DOCS.md`
  - `.agent/PLANS.md`
  - `.agent/modules/requirements.md`
  - `.agent/modules/planning.md`
- Manual:
  - `docs/plans/manuals/requirements_closure_workflow.md`
  - `docs/plans/manuals/planning_annotation_workflow.md`
- Canonical Docs:
  - `docs/plans/requirements.md`
  - `docs/plans/open_questions.md`

## Plan of Work
1. 依頼から Goal、Deliverables、Constraints、Acceptance、NFR、Dependencies を抽出する。
2. 確定事項を `requirements.md` に記入する。
3. 未決事項を `open_questions.md` に分離する。
4. question batch と recommended default を整理する。
5. ExecPlan 側の `Requirements Status`、`Approval Needed`、`Verification Gate` を同期する。

## Concrete Steps
1. 依頼文を読み、要件の確定 / 未確定を仕分ける。
2. `docs/plans/requirements.md` に確定要件だけを記入する。
3. `docs/plans/open_questions.md` に `Q-ID`、priority、signal、blocker、why_it_matters、recommended_default を記入する。
4. `red` signal がある場合は question batch を提示し、回答待ちで停止する。
5. `yellow` / `green` signal は根拠と影響を plan へ記録する。

## Validation and Acceptance
- 受け入れ条件:
  - requirements closure workflow と open questions register が存在する。
  - `red` signal blocker が plan と open questions に明示される。
  - initialization / README / module から運用導線へ辿れる。
- 検証例:
  - `test -f .agent/modules/requirements.md`
  - `test -f docs/plans/open_questions.md`
  - `test -f docs/plans/manuals/requirements_closure_workflow.md`
  - `rg -n "open_questions\\.md|requirements_closure_workflow|Requirements module" AGENTS.md .agent docs/plans README.md docs/initialization/initialization_prompt.md`

## Idempotence and Recovery
- 文書は追記または参照更新を基本とし、再実行しても同じ requirements / open questions へ収束する。
- blocker ルールが過剰だと判明した場合は、削除ではなく `Decision Log` と `plans.md` に再判断を残す。

## Artifacts and Notes
- Canonical Docs:
  - `docs/plans/requirements.md`
  - `docs/plans/open_questions.md`
- Workflow:
  - `.agent/modules/requirements.md`
  - `docs/plans/manuals/requirements_closure_workflow.md`
- Companion Blueprint:
  - `docs/plans/blueprints/single_plan_orchestration_blueprint.md`

## Interfaces and Dependencies
- 依存:
  - plan-first 運用
  - append-only 記録ルール
  - requirements / open questions の役割分離
- interface change:
  - 単一プロンプト運用に requirements closure gate を追加する。

## Related References
- Manual:
  - `docs/plans/manuals/requirements_closure_workflow.md`
  - `docs/plans/manuals/planning_annotation_workflow.md`
- Canonical Docs:
  - `docs/plans/requirements.md`
  - `docs/plans/open_questions.md`
- Companion Blueprint:
  - `docs/plans/blueprints/single_plan_orchestration_blueprint.md`
