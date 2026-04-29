# Implementation Module

## When To Read
- 実装を開始するとき
- root / module / data の境界に触れる変更を行うとき

## Rules
- ExecPlan がある変更では plan を正本にして進める。
- 変更は最小差分で行い、不要な scope 拡大を避ける。
- minimal impact を独立原則として維持する。
- `AGENTS.md` は router、`.agent/*` は policy / module、`work/memory/*` は data として役割を混ぜない。
- 関連ドキュメント更新を実装と同期する。
- append-only 文書と JSONL は追記を基本とし、過去記録を破壊しない。
- root cause を取れない temporary fix は採らない。
- non-trivial change で fix が hacky に見える場合は、より elegant な解を再検討する。ただし単純修正では過剰設計しない。
- bug report、logs、errors、failing tests がある場合は、それらを起点に自律的に解決する。
- `docs/plans/open_questions.md` に `red` signal の未解決事項や未承認項目が残る場合は実装を開始しない。
- 方向が外れた場合は継ぎ足しより停止・再計画を優先する。

## Routing
- 要件確定は `.agent/modules/requirements.md`
- 検証手順は `.agent/modules/verification.md`
- memory 設計は `.agent/modules/memory.md`
- context 全体像は `docs/plans/manuals/context_architecture_for_agents.md`
