# Background Agent Operations

## 目的
- 背景エージェントを「役に立つときだけ」回し、日次運用の暖機に使う。
- mistake を運用ルールかツールへ還元し、次回以降の失敗率を下げる。

## 導入順序
1. まず chatbot ではなく agent を主手段にする。
2. 自分の手作業を agent に再現させる段階を通る。
3. 検証手段を与え、自己修正しやすい harness を用意する。
4. 背景実行は EOD から始め、常時複数ではなく 1 agent を基本にする。

## EOD agent の回し方
1. 仕事終わりの 30 分で、翌朝役立つ task を 1 つか少数に絞る。
2. 依頼内容は報告重視にする。
   - deep research
   - issue / PR triage
   - vague idea の並列探索
3. triage 系は report-only にする。
   - agent に外部返信や merge をさせない。
4. 翌朝に報告を読み、価値が高いものだけ次の task へ昇格させる。

## Slam Dunk 委譲
- 高確度で mostly-correct を期待できる task だけを委譲する。
- 一度に複数本は流さず、まず 1 本だけ背景実行する。
- 人間は別の深い仕事を続け、自然な休憩時だけ agent を確認する。
- 通知は切る。割り込み時点は人間が決める。

## 単一計画書との接続
- background agent は canonical plan の owner ではなく、main agent 配下の report-only worker として扱う。
- 切り出す task は deep research、triage、候補比較のような read-heavy なものに限る。
- background agent は shared write surface や canonical plan を直接更新しない。
- 背景結果の採用、defer、reject は main agent が plan の `Decision Log` と `Next Action` へ反映する。

## Harness Engineering
1. agent が Bad Thing をしたら再発防止を先に設計する。
2. 軽い失敗は `AGENTS.md` や manual にルール化する。
3. 繰り返す失敗は script や validator に落とす。
4. 再現確認まで終えたら `implementation_summary.md` に証跡を残す。

## 向かない task
- 曖昧で success 条件がない task。
- 人間の即時判断が連続で必要な task。
- 外部への返信や最終承認が必要な task。

## 毎日の確認
- 背景実行中の agent は 0 か 1。
- triage は report-only。
- notifications は off。
- 今日見つけた失敗は AGENTS / tool / manual のどこに還元するか決めた。

## Related References
- Manual:
  - `docs/plans/manual.md`
  - `docs/plans/manuals/planning_annotation_workflow.md`
- Blueprint:
  - `docs/plans/blueprints/single_plan_orchestration_blueprint.md`
