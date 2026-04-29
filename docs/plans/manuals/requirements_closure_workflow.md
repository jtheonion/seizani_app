# Requirements Closure Workflow

## 目的
- 単一プロンプトの依頼に残る要件不足を、実装前に検知して整理する。
- 確定要件と未決事項を分離し、質問回数を増やすのではなく高価値な質問 batch で解消する。

## いつ使うか
- 依頼文だけでは受け入れ条件、制約、NFR、設計方針が確定しないとき。
- 外部公開、法務、規約、課金、セキュリティ、データ破壊のいずれかに触れるとき。
- plan mode に入る前に requirements closure を済ませたいとき。

## Phase 0: Requirements Closure
1. 依頼文から確定事項を抽出する。
   - `Goal`
   - `Deliverables`
   - `Constraints`
   - `Acceptance`
   - `NFR`
   - `Dependencies`
2. 確定した内容だけを `docs/plans/requirements.md` に記入する。
3. 決め切れない内容は `docs/plans/open_questions.md` へ分離する。
4. 質問は 1 件ずつ増やさず、価値の高い順に 3-7 件の batch を作る。
5. 回答待ちの間は `don't implement yet` を維持し、plan と質問集だけを更新する。

## Signal 分類
- `red`
  - 未解決のまま実装禁止。
  - 例: 外部公開挙動、課金、法務、規約、セキュリティ、データ破壊、承認必須項目。
- `yellow`
  - 推奨デフォルトまたは明示した仮定つきで一時進行できる。
  - 仮定、影響、ロールバック条件を ExecPlan と最終報告へ残す。
- `green`
  - local default で処理してよい。
  - ただし requirements / plan へ採用した default を残す。

## Question Batch Rules
- batch は `high priority` の質問を優先し、長くても 7 件程度に抑える。
- 各質問には `Q-ID`、priority、signal、blocker、why_it_matters、recommended_default を付ける。
- 低価値な確認や枝葉の好みは、`red` / `yellow` が潰れるまで後ろへ送る。
- 新しい blocker が出たら、既存 batch を閉じてから次の batch を作る。

## Artifacts
- 確定要件:
  - `docs/plans/requirements.md`
- 未決事項:
  - `docs/plans/open_questions.md`
- 進行中 plan:
  - ExecPlan の `Requirements Status`、`Approval Needed`、`Verification Gate`

## チェック項目
- requirements 本体に未決事項が混ざっていない。
- `open_questions.md` に blocker と推奨デフォルトがある。
- 質問が 1 件ずつ散発せず、batch 化されている。
- `red` signal 未解決のまま実装に進んでいない。
- 回答反映後に requirements と ExecPlan が同期されている。

## Related References
- Module:
  - `.agent/modules/requirements.md`
  - `.agent/modules/planning.md`
- Manual:
  - `docs/plans/manuals/planning_annotation_workflow.md`
- Canonical Docs:
  - `docs/plans/requirements.md`
  - `docs/plans/open_questions.md`
- Plan:
  - `docs/plans/blueprints/requirements_closure_gate_blueprint.md`
  - `docs/plans/blueprints/single_plan_orchestration_blueprint.md`
