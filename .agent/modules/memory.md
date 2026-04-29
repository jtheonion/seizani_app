# Memory Module

## Purpose
- append-only な判断・経験・失敗の記録を `work/memory/` に集約する。
- facts だけでなく judgment を残し、後続の判断に再利用できる形にする。

## Files
- `work/memory/decisions.jsonl`
- `work/memory/experiences.jsonl`
- `work/memory/failures.jsonl`

## Related Store
- `docs/plans/bestpractice/lessons.md`
  - user correction や recurring failure から抽出した generalized rule の append-only store。

## Rules
- 1 行目は schema line とする。
- 以後の record は append-only で追加する。
- 無効化は削除ではなく `status: archived` を使う。
- record には `source_doc` を入れ、根拠へ戻れるようにする。
- 関連判断は `related_decision_id` で結ぶ。
- 履歴ファイルと結ぶ必要がある場合は `related_history_file` を使う。
- `work/memory/failures.jsonl` は concrete incident を残す。
- `docs/plans/bestpractice/lessons.md` は reusable rule を残す。

## Lookup Chains
- rule lookup:
  - `AGENTS.md` -> `.agent/modules/planning.md` / `.agent/modules/verification.md` -> `docs/plans/bestpractice/lessons.md` -> manual / evaluation
- failure lookup:
  - `.agent/modules/verification.md` -> `work/memory/failures.jsonl` -> `source_doc` / `related_history_file`
- failure-to-lesson lookup:
  - `work/memory/failures.jsonl` -> `docs/plans/bestpractice/lessons.md` -> next similar task
- decision lookup:
  - `AGENTS.md` -> `.agent/modules/memory.md` -> `work/memory/decisions.jsonl` -> `source_doc`
