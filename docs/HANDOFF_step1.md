# 引き継ぎメモ: Step 1（2026/11/20 データでの条件単位交差検証）

GPU PC 上の Claude Code 向け。コードは別の PC（Windows）で書き、GitHub 経由で受け取る。
この PC の役割は **MATLAB で実行し、結果を集計して報告すること**。コードの設計変更は勝手にせず、
問題があれば内容を報告して利用者に確認すること。

## 背景（要点だけ）
- 研究: 水平管（内径 15 mm）の気液二相流の流動様式を、静電容量（→ボイド率）とベンチュリ差圧の
  2ch 時系列（100 Hz、4 秒 = 400 点）から biLSTM で判別する。
- 2026/11/20 の実験: 作動流体 KF-96L-1cs、20 条件 × 20 秒。流動様式ごとに 5 条件
  （層状流 L0.3G1〜G3、プラグ流、スラグ流、気泡流）。
- 動画で確認済み: **層状流（L0.3）の記録には 8〜10 秒ごとに液の橋（スラグ）が来る**。
  L6G1/L6G3 はプラグ流と気泡流が混ざる。
- Step 1 の目的: 層状流の 20 秒すべてを「層状流」として学習・テストし、
  **液の橋を含む窓で正解率が下がること**を示す →「遷移は別に扱う」という流れの根拠にする。

## 準備
1. データの配置（リポジトリのルートから見て）:
   ```
   resources/data/20261120/<条件>/ALLDATA.csv   (L0.3G1, ..., L10G3, test002 を含む)
   resources/data/20251114/..., resources/data/20251117/...   (Step 2 で使う)
   ```
   `resources/data/` は Git に入れないこと（.git/info/exclude に追加するとよい）。
2. ブランチ: `git fetch && git switch feat/2026-data-step1`

## 実行
MATLAB（Deep Learning Toolbox が必要）で、リポジトリのルートから:
```
matlab -batch "quickTest=true; runSeed=1; deepLearning_wave_2026_conditionCV"
```
まず `quickTest=true`（2 エポック・窓を間引く）で最後まで通ることを確認する。通ったら本番:
```
matlab -batch "runSeed=1; deepLearning_wave_2026_conditionCV"
matlab -batch "runSeed=2; deepLearning_wave_2026_conditionCV"
matlab -batch "runSeed=3; deepLearning_wave_2026_conditionCV"
```

## 最初に確認すること（quickTest の段階で）
- 表示される「静電容量の基準: 気相 148.0 fF, 液相 約329 fF」になっているか
  （液相は test002 の平均。ずれていたら CapacitanceReference.m / resolveCapacitanceCalibration.m を疑う）。
- 「流動様式: Stratified, Plug, Slug, Bubbly」の 4 つになっているか（Unknown が出たらラベルの設定漏れ）。
- 差圧の平均がおおよそ次の値か（前処理前の解析値）: L0.3 系 ≈ 0.6〜1 kPa、L6G20 ≈ 95 kPa、L10G3 ≈ 105 kPa。
- GPU が使われているか（`canUseGPU` が true か）。

## 出力（results/step1_conditionCV/<日時>_seed<種>/）
- `summary.txt` … 全体と流動様式ごとの正解率、層状流の窓を液の橋の有無で分けた正解率
- `perCondition.csv` … 条件ごとの正解率
- `stratifiedByBridge.csv`, `stratifiedPredictedByBridge.csv` … 層状流の窓: bridge / partial / none 別の正解率と予測先
- `windows.csv` … テストの全窓（分割、条件、正解、予測、各クラスの確率、液の橋の割合）
- `confusion.png`, `stratified_timeline_<条件>.png`（静電容量と各クラスの確率の時間変化）

## 報告してほしいこと
3 つの種それぞれについて、`summary.txt` の内容と、`stratifiedByBridge.csv` の表。
加えて、3 つの種の平均と標準偏差（全体の正解率、層状流の bridge / partial / none 別の正解率）。
`stratified_timeline_*.png` で、液の橋が来るたびにスラグ流の確率が上がっているかの所見。

## 液の橋の判定（暫定）
- bridge: 窓の中で静電容量 ≥ 311 fF（満管 329 fF の約 0.9）が 5 点（0.05 s）以上
- partial: bridge ではなく、275〜311 fF が 5 点以上（届きかけの波・擬似スラグ）
- none: それ以外
しきい値の決め方は文献調査中で、後で感度（しきい値を変えた結果）を確認する予定。

## 既知の注意点
- 既存の `deepLearning_wave_conditionHoldout.m` と `TrainTestDataCreatorWave` は、
  訓練とテストを別々に標準化している・テスト条件が切り捨てられるなどの問題があるので、Step 1 では使わない。
- 公開リポジトリには `preprocessFlowData`, `thresholdL2Norm`, `stopIfAccuracyNotImproving` が無い。
  Step 1 のスクリプトは学習ループを自前で持っているので、これらは不要。
