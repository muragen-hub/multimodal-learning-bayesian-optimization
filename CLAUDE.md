# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A MATLAB codebase (no Python, no JS) implementing deep-learning pipelines for two-phase flow regime classification (Stratified / Bubbly / Slug / Plug / Annular) from time-series sensor waveforms (capacitance, differential pressure) plus derived scalar features. It includes a multimodal (multi-branch LSTM) classifier, a single-waveform baseline for comparison, custom loss functions (label smoothing), and Bayesian hyperparameter optimization via `bayesopt`.

This is a portfolio subset of a private lab monorepo — raw experiment data, other members' code, and internal paths are intentionally excluded (see `.gitignore`: `data/raw/`, `data/private/`, `results/private/`, `checkpoints/`).

Code comments and identifiers are predominantly in Japanese; match that convention when editing existing files.

## Running / testing (MATLAB only — no build system)

There is no package manager, linter, or test runner. Everything executes inside MATLAB.

- **Requires**: MATLAB with Deep Learning Toolbox (uses `bilstmLayer`, `trainNetwork`, `dlnetwork`/`dlfeval`/`adamupdate`, `trainingProgressMonitor`, `layerGraph`, `bayesopt`).
- **Entry points** are the `.mlx` Live Scripts at repo root, run cell-by-cell in MATLAB, not from a CLI:
  - `deepLearning_wave_multimodalClassification.mlx` — main, verified multimodal (dual-waveform + feature) pipeline.
  - `deepLearning_one_wave_multimodalClassification.mlx` — verified single-waveform baseline, for comparison against the multimodal model.
  - `deepLearning_2_multimodal_flow_regime.mlx` / `singleWave_FlowRegime.mlx` — work in progress, not fully verified; treat as unstable.
  Each script walks the numbered folders in order (`00_setup` → `10_bayesian_optimization`), matching the README's documented pipeline stages.
- **"Tests"**: scattered `*Test.m` files (e.g. `00_setup/filtering/default/compactRangeArrayTest.m`) are plain scripts that call a function with sample inputs and print/plot results for manual inspection — not `matlab.unittest.TestCase` classes. Run them by opening in MATLAB and executing (F5/Run); there's no automated test suite or assertions to check programmatically.
- Raw data is expected under `resources/data/<date>/<condition>/ALLDATA.csv` (path built from `configs/PathConfig/DataPath.m`), which is not included in this public repo — pipeline code cannot be executed end-to-end without private lab data.

## Architecture

### Numbered pipeline folders = linear data flow

Folders `01_raw_data_import` through `10_bayesian_optimization` are stages, in order, of one linear pipeline (00_setup is pre-run housekeeping like `clc; clear; close all hidden;`, not a pipeline stage). Each stage is implemented as MATLAB `classdef` files, generally following a Factory pattern: a `*Creator` class builds the stage's data-holding class from the previous stage's output.

Reference chain for the main "Two" pipeline (dual waveform + feature, multimodal):

```
RawDataCreatorTwo.create(...)              → RawDataTwo            (01_raw_data_import)
PreProcessorBeforeFormatTwo.process(...)   → ModifiedDataBeforeFormatTwo (02_preprocessing/BeforeFormat)
DataFormatterCreatorTwo(option).create()   → DataFormatterTwo → FormattedDataTwo (03_formatting_augmentation)
TrainTestDataCreatorTwo...                 → TrainTestDataTwo       (04_train_test_dataset)
cellInputStandardizeWave-family functions  → z-scored FeatureData   (05_feature_standardization)
LayerSettingCreatorTwo / TrainOptionCreatorTwo → layers + trainingOptions (06_training_settings)
TrainActivatorTwo.<activate*>(...)         → TrainResult, saved .mat (07_training)
ResultDisplayerTwo.displayResult(...)      → figures + summary txt  (08_result_display)
09_custom_loss/*                            → loss function handles used by TrainActivatorTwo.customLossFuncActivate
optimizeModelTwo(params)                    → bayesopt objective function (10_bayesian_optimization)
```

### Experiment-variant naming suffix (important — code is duplicated per variant, not shared)

Nearly every stage has parallel sibling classes distinguished by a naming suffix, which encodes which experiment input configuration they support. There is **no shared base class** across these — they are independent, largely copy-pasted implementations. When changing pipeline behavior, check whether the same fix needs to be applied to each sibling:

- **(no suffix)** — original/legacy single-input version (e.g. `RawData`, `TrainTestData`).
- **`Two`** — dual-waveform (capacitance + differential pressure) + feature-vector multimodal path. This is the most actively developed / reference implementation (used by the main verified Live Script).
- **`Wave`** — wave-only multimodal variant.
- **`OneWave`** / **`Single`** — single time-series waveform input, used as the comparison baseline against multimodal models.

### `configs/` — experiment parameters as static classes, not config files

Configuration lives in `classdef ... properties (Constant)` classes, not JSON/YAML:
- `configs/Condition/Conditions.m` — named sets of experiment condition strings (e.g. `c22`, `c28`, flow-rate labels like `"L6G1"`), one set per historical experiment batch.
- `configs/Condition/CorrectFlowRegimes.m` / `CorrectConditions.m` — ground-truth condition→flow-regime mappings (mirrors the lookup tables hardcoded in `RawDataCreatorTwo.correctFlowRegime`; keep both in sync if changed).
- `configs/PathConfig/*.m` — centralized I/O roots: `DataPath.path` (`resources/data/`, not present in this repo), `deepNetSavePath.path` (`nets/`), `PictureSavePath.path`.

### Key invariants to preserve when touching pipeline code

- **Standardization must not leak test data**: `05_feature_standardization` computes mean/std from training data only and applies those stats to both train and test FeatureData (called out explicitly in README). Any refactor of `cellInputStandardize*`/`standardize.m` must preserve train-only statistics.
- **`PreProcessorBeforeFormat*` is a functional middleware pipeline**: its constructor takes an ordered `cell` array of function handles, each `@(rawData, rawAllDataBeforeFormat) -> RawData`, applied in array order. Order matters (e.g. correction must run before standardization) — see comments in `PreProcessorBeforeFormatTwo.m`.
- **Outlier handling correlates signals**: `RawDataCreatorTwo.create` detects outliers independently on capacitance and differential pressure (`rmoutliers`), then unions the two index masks so an outlier in either signal NaNs out both signals plus flow rates at that index — don't detect/replace per-signal only.
- **Custom loss functions have a two-level call signature**: functions in `09_custom_loss/` (e.g. `multiCrossEntropyLoss.m`) are called as `dlfeval(lossFunc(labelOutPutLayerName), net, data, label)` — i.e. the loss function itself takes the output layer name and returns a function of `(net, data, label)`. Match this shape when adding a new custom loss.
- **`TrainActivatorTwo` has four distinct training entry points**, chosen based on input/loss configuration, not one unified `train()`:
  - `activate()` — single input, high-level `trainNetwork`.
  - `activateDualWave()` — two waveform inputs (cap + diff), high-level `trainNetwork` multi-input API.
  - `customLossFuncActivate(labelOutPutLayerName, lossFunc, dirName)` — manual `dlnetwork`/`dlfeval`/`adamupdate` loop with validation-based early stopping, for custom losses.
  - `customActivateMultimodal()` — manual training loop over `combine(arrayDatastore(...))` datastores for the full 3-branch (cap + diff + feature) input, with local `modelGradients`/`evaluateMetrics` helpers.
  All persist to `nets/<netSaveDirectory>/<netSaveName>.mat` and append accuracy to `nets/accuracy.txt`.
- **`optimizeModelTwo.m` (bayesopt objective) has machine-specific state**: it `load('trainDataInstance.mat')`/`load('testDataInstance.mat')` from the current working directory (must be saved there by the Live Script beforehand) and writes bayesopt run logs to a hardcoded absolute path (`/home/twophaseflow/deepLearningForMultiMeter/...`) from the original author's machine — this path needs local editing before it will run elsewhere, it is not repo-portable data.
