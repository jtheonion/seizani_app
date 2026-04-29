# codex_home_prerequisites.md
- 最終更新日: 2026-04-30
- バージョン: 0.1

## 目的
- このテンプレートが前提とする global Codex 環境を確認できるようにする。
- ユーザー固有の絶対パスではなく、`~/.codex` または `$CODEX_HOME` を使う運用へ揃える。
- 最新の Codex app で使える repo-local `.codex/` との差分を明示し、このテンプレートの非採用方針を記録する。

## 基本方針
- repo-local `.codex/` は Codex app の公式機能として利用可能。
- ただしこのテンプレートは、shared local environments や project-scoped agent を初期同梱しない。
- 必要になった場合のみ repo-local `.codex/` を追加する。
- Codex の home は `~/.codex` または `$CODEX_HOME` として扱う。
- このテンプレートは `AGENTS.md`、`.agent/`、`docs/plans/` を repo 内の正本とし、global な skill や worktree は補助レイヤーとして使う。

## 確認項目
1. `~/.codex` または `$CODEX_HOME` が利用可能である。
2. global skill を使う場合、`~/.codex/skills` 配下に配置されている。
3. worktree 運用をする場合、`$CODEX_HOME/worktrees` を使う方針がある。
4. global memory や設定を使う場合でも、repo 固有の正本はこのテンプレート内文書に置く。

## 推奨だが必須ではないもの
- requirements 系 skill
- `skill-installer`
- `skill-creator`
- 再利用する internal skill 群

## ドキュメント表記ルール
- starter 内では `/Users/<name>/.codex` のような固定ユーザー名を使わない。
- 説明や導線は `~/.codex` または `$CODEX_HOME` に統一する。
- user ごとの実パス差異は環境変数や shell 展開で吸収する。

## 初回セットアップ時の扱い
- `README.md` と `docs/initialization/initialization_prompt.md` を読む前提に含める。
- global 側に不足があっても、repo 内文書の運用自体は先に開始できる。
- global skill に依存する追加運用は、必要になった時点で別途導入する。
