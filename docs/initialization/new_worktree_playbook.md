# new_worktree_playbook.md
- 最終更新日: 2026-02-10
- バージョン: 1.0

## Purpose / Scope
- 本手順書は、実行時のカレントディレクトリ（`pwd`）を起点に `New Work Tree` 手順を再現するための単一正本である。
- 固定パスを使わず、Git ルートを都度解決して実行する。
- 役割分担:
  - Codex: preflight、HEAD判定、必要時の初回コミット、post-check、記録更新
  - ユーザー: Codex App で `New Work Tree` の UI 実行

## Quick Start
1. preflight を実行する。
2. `HEAD` を判定する。
3. `HEAD` 不在時のみ初回コミットを作成する。
4. ユーザーが Codex App で `New Work Tree` を実行する。
5. post-check を実行する。
6. 実行ログを記録する。

## Preflight Commands
```bash
TARGET_DIR="$(pwd)"
git -C "$TARGET_DIR" rev-parse --is-inside-work-tree
REPO_ROOT="$(git -C "$TARGET_DIR" rev-parse --show-toplevel)"
git -C "$REPO_ROOT" status -sb
git -C "$REPO_ROOT" worktree list
```

- `fatal: not a git repository` の場合は、そのディレクトリで処理を継続しない。
- `TARGET_DIR` がサブディレクトリでも `REPO_ROOT` が解決できれば継続可能。

## HEAD Decision
```bash
TARGET_DIR="$(pwd)"
REPO_ROOT="$(git -C "$TARGET_DIR" rev-parse --show-toplevel)"
git -C "$REPO_ROOT" rev-parse --verify HEAD
```

- 成功時: 初回コミット処理は不要。
- 失敗時（`fatal: Needed a single revision`）: 次の初回コミット手順を実行。

## Initial Commit Procedure (HEAD missing only)
```bash
TARGET_DIR="$(pwd)"
REPO_ROOT="$(git -C "$TARGET_DIR" rev-parse --show-toplevel)"

if ! rg -qxF '.DS_Store' "$REPO_ROOT/.gitignore" 2>/dev/null; then
  printf '.DS_Store\n' >> "$REPO_ROOT/.gitignore"
fi

git -C "$REPO_ROOT" add .
git -C "$REPO_ROOT" commit -m "chore: initialize repo for codex worktree"
git -C "$REPO_ROOT" rev-parse --verify HEAD
```

## Codex App New Work Tree Procedure (User Action)
1. Codex App の New Thread Composer を開く。
2. `Environment` を `Worktree` に設定する。
3. `Starting branch` を選択する（通常は `main`）。
4. 第一候補のブランチ名として `codex/new-worktree-YYYYMMDD-HHMM` を指定して実行する。

## Fallback Rule
- `refs/heads/codex/...` 作成失敗時は、以下で再実行する。
- `codex-worktree-YYYYMMDD-HHMM`

## Post-check
```bash
TARGET_DIR="$(pwd)"
REPO_ROOT="$(git -C "$TARGET_DIR" rev-parse --show-toplevel)"
git -C "$REPO_ROOT" worktree list
git -C "$REPO_ROOT" branch --list
git -C "$REPO_ROOT" status -sb
```

## Logging Rule
- 追記先決定ルール:
  - `"$REPO_ROOT/docs/plans/implementation_summary.md"` が存在する場合はそこへ追記する。
  - 存在しない場合は `"$TARGET_DIR/new_worktree_prep_log.md"` を作成して追記する。
- 記録必須項目:
  - 実施コマンド
  - 成功/失敗結果
  - フォールバック有無
  - 最終報告（`ドキュメント更新済み: はい`）

## Troubleshooting
- `fatal: not a git repository (or any of the parent directories): .git`
  - 原因: Git 管理外ディレクトリで実行している。
  - 対応: Git 管理下ディレクトリへ移動して再実行する。
- `fatal: Needed a single revision`
  - 原因: 初回コミット未作成で `HEAD` が存在しない。
  - 対応: `Initial Commit Procedure` を実行する。
- `refs/heads/codex/...` 作成失敗
  - 原因: ローカル環境の制約で `codex/` 形式ブランチ作成に失敗している。
  - 対応: `Fallback Rule` の命名で再実行する。

## Validation Checklist
- [ ] Preflight の4コマンドが実行できる。
- [ ] `HEAD` 判定分岐が明確に実行できる。
- [ ] `HEAD` 不在時のみ初回コミットを作成する。
- [ ] UI 実行後に `worktree list` / `branch --list` / `status -sb` を確認した。
- [ ] 非Gitディレクトリ時に即停止できる。
- [ ] 実施ログを規定の追記先へ記録した。

## Official References
- https://developers.openai.com/codex/app/worktrees
- https://developers.openai.com/codex/app/local-environments
- https://git-scm.com/docs/git-worktree

## Decision Log (Merged from ExecPlan)
- 固定パス依存を廃止し、`TARGET_DIR="$(pwd)"` 起点に統一した。
- ログ追記先は `implementation_summary.md` 優先、未存在時は `new_worktree_prep_log.md` 作成に統一した。
- `codex/...` 失敗時のフォールバック命名を `codex-worktree-YYYYMMDD-HHMM` とした。
