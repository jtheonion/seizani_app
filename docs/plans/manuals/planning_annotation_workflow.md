# Planning Annotation Workflow

## 目的
- 非 trivial 作業を「調査 -> 計画 -> 注釈 -> 実装 -> 検証」で進める。
- plan を shared mutable state として扱い、実装前に判断を出し切る。

## いつ使うか
- 3 ステップ以上の作業。
- 設計判断がある変更。
- 途中で想定外が出たら再計画したい作業。

## 手順
1. Phase 0 として requirements closure を先に行う。
   - 確定要件は `requirements.md`、未決事項は `open_questions.md` へ分離する。
   - 質問は 1 件ずつ増やさず、高価値な 3-7 件の batch へまとめる。
   - `red` signal の未決事項がある間は `don't implement yet` を維持する。
2. 深掘り調査を先に依頼する。
   - 依頼は「deeply」「in great detail」相当の粒度を要求し、結果は永続 Markdown に残す。
3. 調査結果をレビューしてから plan を別 Markdown に切り出す。
   - 実装はまだ始めず、変更対象、detailed spec、検証、ロールバックを plan に固定する。
4. plan には granular todo を upfront で入れる。
   - phase と task をチェック可能な粒度まで分解し、進捗正本を plan に一本化する。
5. 類似タスクなら `docs/plans/bestpractice/lessons.md` を先に確認する。
   - 過去の correction や recurring failure から抽出した rule を再利用する。
6. plan に inline note を追記して注釈サイクルを回す。
   - 注釈では制約追加、誤り修正、不要案の削除、既存実装参照の指定を行う。
   - 各反復で `don't implement yet` を明示し、plan 更新だけをさせる。
7. 調査・探索・並列分析を切り出すときは、1 subtask = 1 subagent を原則にする。
   - main agent は最終判断と整合確認を担当する。
8. 実装開始後も plan を正本にする。
   - task 完了ごとにチェックを更新し、節目ごとに高レベル要約を残す。
9. verification も plan の一部として扱う。
   - 想定外、方針逸脱、hacky な修正、失敗検証が出たら止めて plan に戻る。
10. 最後に diff / tests / logs で正しさを証明する。
   - 「staff engineer が承認できるか」を基準に自己レビューする。
11. user correction や recurring failure が出たら lesson を残す。
   - concrete incident は `work/memory/failures.jsonl`
   - reusable rule は `docs/plans/bestpractice/lessons.md`

## 単一計画書オーケストレーション
- 単発依頼を 1 回の流れで完走させたい場合でも、plan を分散させず 1 本の ExecPlan を正本にする。
- その plan には少なくとも `Requirements Status`、`Current Goal`、`Active Milestone`、`Delegation Map`、`Verification Gate`、`Next Action` を持たせる。
- 未決事項は `open_questions.md` を正本とし、plan には blocker と次の質問 batch だけを残す。
- `/compact`、`/resume`、`/fork` を使う前に、次の一手と未解決 blocker を plan へ残す。
- subagent は read-heavy task のみを扱い、main agent が plan 更新と最終判断を維持する。

## 実務ルール
- 実装は boring であるべきで、創造性は注釈サイクルで使い切る。
- 方針が外れたら incremental patch ではなく revert-and-rescope を優先する。
- 既存 UI や OSS 実装が良い参照なら、plan 作成時点で入力として渡す。
- correction は長文でなくてよい。実装中は短い指示で十分。
- temporary fix より root cause 解決を優先する。
- non-trivial change で hacky に見えるなら elegance review を入れる。

## チェック項目
- plan mode の発火条件を満たしている。
- requirements closure または closure 不要判断がある。
- 調査ノートがある。
- plan が別ファイルで存在する。
- inline note の反映履歴がある。
- todo が plan に入っている。
- lesson の確認または lesson 不要判断がある。
- 完了前に tests / logs / diff を確認した。

## Related References
- Manual:
  - `docs/plans/manual.md`
  - `docs/plans/manuals/requirements_closure_workflow.md`
- Blueprint:
  - `docs/plans/blueprints/single_plan_orchestration_blueprint.md`
  - `docs/plans/blueprints/requirements_closure_gate_blueprint.md`
