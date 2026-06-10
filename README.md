# Multimodal Deep Learning with Bayesian Optimization in MATLAB

A MATLAB implementation of deep learning pipelines for flow regime classification, including multimodal time-series classification and Bayesian hyperparameter optimization.

## 概要

本リポジトリは、MATLABを用いて実装した、流動様式判別のための深層学習モデル群です。

主に、時系列波形データや特徴量データを用いた分類モデルを扱っています。  
動作確認済みの Live Script では、以下の2種類の実験を確認できます。

- 複数種類の入力を用いたマルチモーダル分類
- 1種類の時系列データを入力とした分類

また、ベイズ最適化によるハイパーパラメータ探索や、Label Smoothingなどのカスタム損失関数の検証用コードも整理しています。

研究室の共同リポジトリ全体は非公開ですが、本リポジトリには自分が作成し、公開可能なコードのみを掲載しています。

---

## 動作確認済みの Live Scripts

現在、主に動作確認している Live Script は以下です。

### `deepLearning_wave_multimodalClassification.mlx`

マルチモーダル分類を行う Live Script です。

複数種類の入力データを組み合わせ、流動様式判別のための深層学習モデルを構築・訓練します。

主な処理内容は以下です。

1. Excelデータの取り込み
2. 前処理
3. スライディングウィンドウ法によるデータ拡張
4. 訓練データ・テストデータの作成
5. FeatureDataのZ-score標準化
6. 訓練オプションとネットワーク層の設定
7. マルチモーダル深層学習モデルの訓練
8. 結果の表示
9. ベイズ最適化によるハイパーパラメータ探索

---

### `deepLearning_one_wave_multimodalClassification.mlx`

1種類の時系列データを入力として分類を行う Live Script です。

マルチモーダル分類との比較対象として、単一の波形入力を用いた分類実験を行います。

---

## 作成途中の Live Scripts

以下の Live Script は作成途中であり、現時点では完全には動作確認していません。

### `deepLearning_2_multimodal_flow_regime.mlx`

流動様式判別を目的としたマルチモーダル学習用の Live Script です。  
今後、メインの実行ファイルとして整理する予定です。

---

### `singleWave_FlowRegime.mlx`

単一波形入力による流動様式判別用の Live Script です。  
現在は実装途中であり、動作確認中です。

---

## 処理の流れ

本リポジトリでは、主に以下の流れで処理を行います。

1. ワークスペースの初期化
2. Excelデータの取り込み
3. 前処理
4. スライディングウィンドウ法によるデータ拡張
5. 訓練データ・テストデータの作成
6. FeatureDataのZ-score標準化
7. 訓練オプションとネットワーク層の設定
8. 深層学習モデルの訓練
9. 結果の表示
10. Label Smoothingなどのカスタム損失関数の検証
11. ベイズ最適化によるハイパーパラメータ探索

---

## ディレクトリ構成

```text
.
├── 00_setup/
├── 01_raw_data_import/
├── 02_preprocessing/
├── 03_formatting_augmentation/
├── 04_train_test_dataset/
├── 05_feature_standardization/
├── 06_training_settings/
├── 07_training/
├── 08_result_display/
├── 09_custom_loss/
├── 10_bayesian_optimization/
├── configs/
├── nets/
├── .gitignore
├── README.md
├── deepLearning_wave_multimodalClassification.mlx
├── deepLearning_one_wave_multimodalClassification.mlx
├── deepLearning_2_multimodal_flow_regime.mlx
└── singleWave_FlowRegime.mlx
```

---

## 各フォルダの役割

### `00_setup/`

MATLABの実行環境を整えるための処理を格納しています。

主に、ワークスペースの初期化や図の削除など、実験開始前に行う処理を管理します。

例：

```matlab
clc;
clear;
close all hidden;
```

---

### `01_raw_data_import/`

Excelデータの取り込みに関するクラスや関数を格納しています。

主に、`RawDataCreatorTwo` などを用いて、訓練用データとテスト用データを作成します。

---

### `02_preprocessing/`

前処理に関する関数やクラスを格納しています。

主な処理内容は以下です。

- データ間隔の統一
- 静電容量を基準とした補正
- 生データを後続処理に適した形式へ変換

---

### `03_formatting_augmentation/`

データ整形とデータ拡張に関する処理を格納しています。

本リポジトリでは、スライディングウィンドウ法を用いて、一定幅のデータをずらしながら切り出すことで学習データ数を増やしています。

主な設定項目は以下です。

- `stride`
- `dataWidth`
- `interval`
- `useWaveform`
- `useFeature`

---

### `04_train_test_dataset/`

訓練データ・テストデータの作成に関する処理を格納しています。

分類モデルで使用する以下の入力データを作成します。

- 静電容量波形データ
- 差分波形データ
- 特徴量データ
- 分類ラベル

---

### `05_feature_standardization/`

FeatureDataに対するZ-score標準化処理を格納しています。

訓練データから平均と標準偏差を計算し、その値を用いて訓練データとテストデータを標準化します。  
これにより、テストデータの情報が訓練時に混入しないようにしています。

---

### `06_training_settings/`

深層学習モデルの訓練設定に関する処理を格納しています。

主な内容は以下です。

- 学習率の設定
- エポック数の設定
- ミニバッチサイズの設定
- 検証頻度の設定
- Early stoppingに関する設定
- 入力データ構成に応じたネットワーク層の構築

---

### `07_training/`

モデルの訓練処理を格納しています。

入力データに応じた学習処理を実行し、訓練済みモデルや学習結果を保存します。

---

### `08_result_display/`

学習結果や評価結果の表示に関する処理を格納しています。

主に、学習結果の可視化や分類結果の確認に使用します。

---

### `09_custom_loss/`

カスタム損失関数に関する処理を格納しています。

例として、Label Smoothingを用いた損失関数を実装しています。  
Label Smoothingは、モデルの過度な自信を抑制する目的で導入しています。

---

### `10_bayesian_optimization/`

ベイズ最適化によるハイパーパラメータ探索処理を格納しています。

探索対象の例は以下です。

- 学習率
- エポック数
- ミニバッチサイズ
- 隠れユニット数

MATLABの `bayesopt` を用いて、効率的にハイパーパラメータを探索します。

---

### `configs/`

実験条件や設定値を管理するためのファイルを格納しています。

コード内に直接値を書き込むのではなく、学習条件やデータ整形条件を設定ファイルとして管理することで、実験条件を変更しやすくしています。

---

### `nets/`

訓練済みネットワークやモデル関連ファイルを格納するためのフォルダです。

公開用リポジトリでは、大容量の学習済みモデルや非公開データに依存するファイルは含めていません。

---

## 使用技術

- MATLAB
- MATLAB Live Script
- Deep Learning Toolbox
- Bayesian Optimization
- Time-Series Classification
- Multimodal Learning
- Sliding Window
- Z-score Standardization
- Custom Loss Function
- Label Smoothing
- Confusion Matrix

---

## 主な実装内容

### 1. Excelデータの取り込み

`RawDataCreatorTwo` を用いて、Excelデータを読み込み、訓練用データとテスト用データを作成します。

---

### 2. 前処理

`PreProcessorBeforeFormatTwo` を用いて、データ間隔の統一や静電容量を基準とした補正を行います。

---

### 3. データ拡張

スライディングウィンドウ法により、一定幅のデータをずらしながら切り出し、学習データ数を増やします。

---

### 4. 入力データの作成

以下の入力データを用いて分類用データを作成します。

- 静電容量波形データ
- 差分波形データ
- 特徴量データ

マルチモーダル分類では、複数種類の入力を組み合わせてモデルに入力します。  
単一波形分類では、1種類の時系列データを入力として使用します。

---

### 5. FeatureDataの標準化

FeatureDataに対してZ-score標準化を行います。  
訓練データから平均と標準偏差を計算し、その値をテストデータにも適用することで、データリークを防いでいます。

---

### 6. 深層学習モデル

時系列波形データや特徴量データを入力として扱う深層学習モデルを構築しています。

動作確認済みの Live Script では、マルチモーダル入力と単一時系列入力の両方を扱っています。

---

### 7. カスタム損失関数

Label Smoothingを用いた損失関数を実装し、モデルの過度な自信を抑制する検証を行っています。

---

### 8. ベイズ最適化

MATLABの `bayesopt` を用いて、学習率、エポック数、ミニバッチサイズ、隠れユニット数などのハイパーパラメータを探索します。

---

## 工夫した点

- 処理の流れに合わせてフォルダを番号順に整理し、データ取り込みからベイズ最適化までの流れを追いやすくしました。
- マルチモーダル分類と単一時系列入力の分類を分けて実装し、入力構成による違いを比較しやすくしました。
- スライディングウィンドウ法により、限られたデータから学習サンプルを増やせるようにしました。
- FeatureDataの標準化では、訓練データのみから平均・標準偏差を算出し、テストデータへの情報漏れを防ぎました。
- Label Smoothingを導入し、モデルの過度な自信を抑制する損失関数を検証しました。
- ベイズ最適化を導入し、ハイパーパラメータ探索を効率化しました。
- 動作確認済みの Live Script と作成途中の Live Script を分けて記載し、利用者が確認すべきファイルを把握しやすくしました。
- MATLAB Projectファイルに依存せず、Live Scriptと関数群で処理を確認できるようにしました。

---

## 注意事項

本リポジトリには、研究室の共同リポジトリ全体、非公開データ、他メンバーのコード、研究室内部のパス情報は含めていません。

公開可能な範囲で、自分が作成したコードを整理して掲載しています。  
一部のデータ、保存先、実験条件は公開用に調整しています。

また、以下の Live Script は作成途中であり、現時点では完全には動作確認していません。

- `deepLearning_2_multimodal_flow_regime.mlx`
- `singleWave_FlowRegime.mlx`

---

## License

This repository is intended for portfolio and reference purposes.
