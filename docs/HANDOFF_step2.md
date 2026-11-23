# 引き継ぎメモ: Step 1 の集計と Step 2（年をまたいだ検証）

GPU PC 上の Claude Code 向け。役割は **MATLAB で実行して結果を報告すること**。コードの設計変更は勝手にせず、
問題があれば内容を報告して利用者に確認すること。背景は docs/HANDOFF_step1.md を参照。

## 注意（先に読むこと）
- Step 1 の本番が `~/step1-2026` で実行中のあいだは、**そのフォルダで `git pull` や `git switch` をしない**
  （MATLAB は種ごとにスクリプトを読み直すので、途中でファイルが変わると 2・3 回目の中身が変わる）。
- 新しいコードは別のフォルダに取ってくる:
  ```bash
  git clone -b feat/2026-data-step2 https://github.com/muragen-hub/multimodal-learning-bayesian-optimization.git ~/step2-crossyear
  ln -s ~/step1-2026/resources ~/step2-crossyear/resources     # データは共有する
  ```

## A. Step 1 の集計（Step 1 の 3 つの種が終わってから）
```bash
cd ~/step2-crossyear
matlab -batch "resultsRoot='$HOME/step1-2026/results/step1_conditionCV'; summarizeStep1" 2>&1 | tee summarize-step1.log
```
`<resultsRoot>/_summary/summary_all.txt` と CSV, `confusion_pooled.png` ができる。`summary_all.txt` の内容を報告する。
（試し実行の結果は `quickTest=0` でないので自動で除かれる。）

## B. Step 2（年をまたいだ検証）
内容: E0 = 2025/11/14 で学習 → 11/17 でテスト（基準）, E1 = 2025 で学習 → 2026 でテスト, E2 = 2026 で学習 → 2025 でテスト。
クラスは層状流・プラグ流・スラグ流の 3 つだけ（片方の年にしかない環状流・気泡流は除く）。

### B-1. 試し実行（最初に必ず）
```bash
cd ~/step2-crossyear
matlab -batch "assert(canUseGPU,'GPU unavailable'); quickTest=true; runSeed=1; deepLearning_wave_crossYear" 2>&1 | tee quicktest-step2.log
```
確認すること:
- 「2025/11/14: 9条件 (Stratified 3 Plug 3 Slug 3 ), 差圧の平均 ... kPa」「2026/11/20: 15条件 (Stratified 5 Plug 5 Slug 5 ...)」と出るか
- 2025 の読み込み中に警告（基準データが見つからない等）が出ていないか（出たら内容を報告）
- E0, E1, E2 がすべて最後まで通り、`results/step2_crossYear/...` に summary.txt ができるか

### B-2. 本番（設定を変えて 4 通り × 種 1〜3）
| 設定 | 意味 |
|---|---|
| A: `standardizeMode="trainStats"; dpHoldSamples=0; channels=[1 2]` | 厳密（標準化は学習データだけ） |
| B: `standardizeMode="ownYear"; dpHoldSamples=0; channels=[1 2]` | テストの年の信号で標準化（装置ごとの較正） |
| C: `standardizeMode="ownYear"; dpHoldSamples=5; channels=[1 2]` | B + 2026年の差圧を約20 Hzに合わせる |
| D: `standardizeMode="ownYear"; dpHoldSamples=0; channels=1` | ボイド率だけ（差圧の違いの影響を除く） |

種 1 で A〜D を先に回し、結果を見てから種 2・3 を回す:
```bash
cd ~/step2-crossyear
nohup bash -c '
for s in 1; do
  matlab -batch "runSeed=$s; standardizeMode=\"trainStats\"; dpHoldSamples=0; channels=[1 2]; deepLearning_wave_crossYear" > step2-A-seed$s.log 2>&1
  matlab -batch "runSeed=$s; standardizeMode=\"ownYear\";   dpHoldSamples=0; channels=[1 2]; deepLearning_wave_crossYear" > step2-B-seed$s.log 2>&1
  matlab -batch "runSeed=$s; standardizeMode=\"ownYear\";   dpHoldSamples=5; channels=[1 2]; deepLearning_wave_crossYear" > step2-C-seed$s.log 2>&1
  matlab -batch "runSeed=$s; standardizeMode=\"ownYear\";   dpHoldSamples=0; channels=1;     deepLearning_wave_crossYear" > step2-D-seed$s.log 2>&1
done' > /dev/null 2>&1 &
```

### 報告してほしいこと
各設定の `summary.txt`（`results/step2_crossYear/<日時>_seed<種>_<設定>/`）。特に
E0 → E1 → E2 の全体の正解率とクラスごとの正解率、条件ごとの予測先。

## 読み方（参考）
- E0 は「同じ装置・別の日」の基準。E1・E2 がそれより大きく下がるなら、装置の違い（喉部径 4→6 mm、流体 0.65cs→1cs、
  差圧の時間分解能、基準値の取り方、層状流の流量が L0.05 と L0.3 で違うこと）が効いている。
- A と B の差 = 標準化（装置ごとの較正）で戻る分。B と D の差 = 差圧を使うことの影響。
