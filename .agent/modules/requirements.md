# Requirements Module

## When To Read
- 依頼文だけでは受け入れ条件や制約が確定しないとき
- 外部公開、課金、法務、規約、セキュリティ、データ破壊に関わる判断があるとき
- plan mode に入る前に requirements closure が必要なとき

## Workflow
1. 依頼から `Goal`、`Deliverables`、`Constraints`、`Acceptance`、`NFR`、`Dependencies` を抽出する。
2. 確定済みの内容だけを `docs/plans/requirements.md` に反映する。
3. 未決事項は `docs/plans/open_questions.md` に分離し、`Q-ID`、優先度、signal、blocker、推奨デフォルト、関連 requirement / plan を付与する。
4. 質問は 1 件ずつではなく、価値の高い順に 3-7 件の batch に束ねて提示する。
5. `red` signal の未決事項、または approval 必須項目が残る場合は、実装せず requirements closure で停止する。
6. `yellow` signal は repo の default policy または明示した仮定で一時進行できるが、ExecPlan と最終報告へ残す。
7. 回答が揃ったら `requirements.md`、`open_questions.md`、ExecPlan を同時に更新してから planning / implementation へ渡す。

## Rules
- `requirements.md` には確定事項のみを書く。
- 未決事項を requirements 本文へ混ぜない。
- 長い質問列ではなく、上位の blocker から順に batch を作る。
- 推奨デフォルトで進む場合は、根拠、影響、ロールバック条件を残す。
- `red` signal 未解決のまま外部公開挙動や破壊的変更を実装しない。

## Routing
- Canonical requirements: `docs/plans/requirements.md`
- Open questions register: `docs/plans/open_questions.md`
- Detailed workflow: `docs/plans/manuals/requirements_closure_workflow.md`
