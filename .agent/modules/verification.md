# Verification Module

## When To Read
- 実装後に affected area を確認するとき
- 完了前の最終確認をするとき

## Workflow
1. 変更領域に対応する最小検証を選ぶ。
2. 必要なら `tests / logs / diff behavior between main and changes` を確認する。
3. 検証コマンドと結果を `docs/plans/implementation_summary.md` に記録する。
4. recurring failure や user correction が出たら、incident は `work/memory/failures.jsonl`、generalized rule は `docs/plans/bestpractice/lessons.md` へ分けて残す。
5. 問題が出たら完了扱いにせず、plan か implementation へ戻る。

## Rules
- 検証なしで完了にしない。
- 失敗が再発しそうなら `work/memory/failures.jsonl` と `docs/plans/bestpractice/lessons.md` への還元を検討する。
- `Would a staff engineer approve this?` を最終セルフチェックにする。
