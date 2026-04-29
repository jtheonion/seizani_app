# AGENTS.md

## Root Contract
- このファイルは L1 router として扱う。詳細手順や長い workflow は `.agent/*` と `docs/plans/manuals/*` に置く。
- 返答と実装記録は日本語を基本にする。
- 不確実な点は実ファイル確認後に判断する。
- スコープ外のディレクトリを無断変更しない。
- 変更は最小差分で行い、破壊的操作は条件付き・冪等手順を優先する。
- 認証情報・秘密情報をコミットしない。

## Routing
- 文書管理ポリシー: `.agent/DOCS.md`
- ExecPlan ポリシー: `.agent/PLANS.md`
- Single-plan orchestration blueprint: `docs/plans/blueprints/single_plan_orchestration_blueprint.md`
- Requirements module: `.agent/modules/requirements.md`
- Planning module: `.agent/modules/planning.md`
- Implementation module: `.agent/modules/implementation.md`
- Verification module: `.agent/modules/verification.md`
- Memory module: `.agent/modules/memory.md`
- Open questions register: `docs/plans/open_questions.md`
- Best practice lessons: `docs/plans/bestpractice/lessons.md`
- Manual index: `docs/plans/manual.md`
- Context architecture: `docs/plans/manuals/context_architecture_for_agents.md`

## ExecPlan Required When
- 複数ファイルにまたがる変更
- 影響範囲が広い仕様変更
- 手順が多段で進捗記録が必要
- 受け入れ条件の検証が複数必要

## Verification And Recording
- この repo でいう「自動反映」は、エージェントが repo-local rule に従って canonical documents へ判断・実装結果を反映する運用を指す。
- これは Git hook、CI、file watcher による技術的な自動実行・自動同期を意味しない。
- 変更領域に対応する最小検証を必ず実施する。
- 実施コマンドと結果を `docs/plans/implementation_summary.md` に記録する。
- 実装結果に応じて関連ドキュメントを同期する。

## Completion Checklist
- [ ] 関連ドキュメント更新を確認した
- [ ] 検証コマンドと結果を記録した
- [ ] 最終報告に「ドキュメント更新済み: はい／いいえ」を明記した
