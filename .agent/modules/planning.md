# Planning Module

## When To Read
- 非 trivial 作業を始めるとき
- ExecPlan が必要な変更を扱うとき
- 想定外が出て再計画が必要なとき

## Read Order
1. `.agent/PLANS.md`
2. 依頼が曖昧なら `.agent/modules/requirements.md`
3. `docs/plans/manuals/planning_annotation_workflow.md`
4. 対象の ExecPlan

## Workflow
1. まず現物を読んで前提を確認する。
2. 要件や受け入れ条件が曖昧なら requirements closure を先に行い、未決事項を `docs/plans/open_questions.md` へ隔離する。
3. clarification は 1 件ずつ増やさず、価値の高い 3-7 件の質問 batch を作る。
4. 必要なら調査ノートを `docs/plans/research/` に残す。
5. 非 trivial 作業では plan mode に入り、ExecPlan に detailed spec と checkable todo を upfront で固定する。
6. 類似タスクや recurring failure がある場合は `docs/plans/bestpractice/lessons.md` の relevant entry を先に確認する。
7. 調査・探索・並列分析を分けるときは 1 subtask = 1 subagent を原則とし、main agent が最終統合を担当する。
8. 進捗は chat ではなく ExecPlan を正本にして更新し、節目ごとに high-level summary を残す。
9. verification も同じ plan の一部として扱い、想定外、方針逸脱、hacky な修正、失敗検証が出たら実装継続より再計画を優先する。

## Rules
- 実装前に判断を出し切る。
- `red` signal の open question や approval 必須項目が未解決なら実装へ進まない。
- discoverable な説明は plan に重複記載しない。
- 詳細 workflow は manual を参照し、root 文書へ戻さない。
- 単発依頼を 1 つの長い flow で回す場合は `docs/plans/blueprints/single_plan_orchestration_blueprint.md` を正本のひな形として使う。
