%% deepLearning_wave_crossYear.m
% Step 2: 年をまたいだ検証. 2025年のデータで学習して2026年でテスト, およびその逆.
%   E0 (基準): 2025/11/14 で学習 → 2025/11/17 でテスト  (同じ装置・同じ条件・別の日)
%   E1       : 2025 (11/14 + 11/17) で学習 → 2026/11/20 でテスト
%   E2       : 2026/11/20 で学習 → 2025 (11/14 と 11/17 それぞれ) でテスト
% 両方の年にある流動様式だけを使う: 層状流 (Stratified), プラグ流 (Plug), スラグ流 (Slug).
%   2025年の環状流 (Annular) と 2026年の気泡流 (Bubbly) は片方の年にしか無いので除く.
%
% 年のあいだの装置の違い (結果の読み方に関わる):
%   ベンチュリ管の喉部の内径 4 mm → 6 mm / 作動流体 0.65cs → 1cs / 差圧の時間分解能 約20 Hz → 100 Hz /
%   ボイド率の基準 (2025: L0G30 と L○G0, 2026: test002 と暫定148 fF) / 層状流の流量 (L0.05 と L0.3)
%
% 使い方 (リポジトリのルートで. 変数は省略可):
%   runSeed = 1;                 乱数の種
%   standardizeMode = "trainStats" | "ownYear"
%       trainStats : 標準化の平均・標準偏差を学習データだけから求める (厳密)
%       ownYear    : テストデータの年の信号の平均・標準偏差 (ラベル不要) で標準化する
%                    = 新しい装置の信号を少しだけ集めて「装置ごとの較正」をする場合に相当
%   dpHoldSamples = 0 | 5        5 にすると 2026年の差圧を 5点保持 (約20 Hz) にして 2025年に合わせる
%   channels = [1 2] | 1 | 2     使う信号 (1 = ボイド率, 2 = 差圧). 1 だけなら差圧の違いの影響が無い
%   quickTest = true             動作確認用 (2エポック, 窓を間引く)
%   例: runSeed = 1; standardizeMode = "ownYear"; deepLearning_wave_crossYear
%
% 出力: results/step2_crossYear/<日時>_seed<種>_<設定>/  summary.txt, windows.csv, perCondition.csv, confusion_*.png

clc;
clearvars -except runSeed quickTest standardizeMode dpHoldSamples channels;
close all hidden;
addpath(genpath(pwd));

if ~exist("runSeed", "var"), runSeed = 1; end
if ~exist("quickTest", "var"), quickTest = false; end
if ~exist("standardizeMode", "var"), standardizeMode = "trainStats"; end
if ~exist("dpHoldSamples", "var"), dpHoldSamples = 0; end
if ~exist("channels", "var"), channels = [1 2]; end
standardizeMode = string(standardizeMode);
assert(ismember(standardizeMode, ["trainStats", "ownYear"]), "standardizeMode は trainStats か ownYear");

cfg.seed = runSeed;
cfg.regimes = ["Stratified", "Plug", "Slug"];
cfg.freq = 100;
cfg.dataWidth = 400;       % 4秒
cfg.trainStride = 2;       % 学習の窓のずらし幅 [点] (Step 1 は 1. 隣の窓はほぼ同じ信号なので 2 にして時間を半分にした)
cfg.testStride = 10;       % テストの窓のずらし幅 [点] (0.1秒)
cfg.learnRate = 0.001;
cfg.maxEpoch = 30;
cfg.batchSize = 64;
cfg.hidden = 320;
cfg.patience = 5;
cfg.standardizeMode = standardizeMode;
cfg.channels = channels;
if quickTest
    cfg.maxEpoch = 2; cfg.trainStride = 20; cfg.testStride = 50;
end

tag = sprintf("%s_dp%d_ch%s", standardizeMode, dpHoldSamples, strjoin(string(channels), ""));
outDir = fullfile("results", "step2_crossYear", string(datetime("now", "Format", "yyyyMMdd_HHmm")) + "_seed" + runSeed + "_" + tag);
mkdir(outDir);
fprintf("設定: seed=%d, %s, 差圧の保持=%d点, 使う信号=%s, quickTest=%d\n", runSeed, standardizeMode, dpHoldSamples, mat2str(channels), quickTest);

%% 1. データの取り込み
S25a = loadFiltered("20251114", Conditions.c12a, Labels.c12a_normal, CorrectConditions.c12a_liquidChange, cfg, 0);
S25b = loadFiltered("20251117", Conditions.c12a, Labels.c12a_normal, CorrectConditions.c12a_liquidChange, cfg, 0);
S26 = loadFiltered("20261120", Conditions.c20_2026, Labels.c20_2026_normal, CorrectConditions.c20_2026_liquidChange, cfg, dpHoldSamples);
describe("2025/11/14", S25a); describe("2025/11/17", S25b); describe("2026/11/20", S26);

%% 2. 実験の定義
exps = {
    "E0_2025a_to_2025b", S25a,        S25b
    "E1_2025_to_2026",   [S25a S25b], S26
    "E2_2026_to_2025",   S26,         [S25a S25b]
};

%% 3. 実行
Ts = cell(size(exps, 1), 1);
for e = 1:size(exps, 1)
    fprintf("\n##### %s #####\n", exps{e, 1});
    Ts{e} = runExperiment(exps{e, 1}, exps{e, 2}, exps{e, 3}, cfg, outDir);
end
T = vertcat(Ts{:});
T.Seed = repmat(runSeed, height(T), 1);
writetable(T, fullfile(outDir, "windows.csv"));

%% 4. 集計
classes = sort(cfg.regimes);
fid = fopen(fullfile(outDir, "summary.txt"), "w", "n", "UTF-8");
emit(fid, "seed=%d, quickTest=%d, 標準化=%s, 差圧の保持=%d点, 使う信号=%s, 学習の窓のずらし幅=%d, 最大エポック=%d\n", ...
    runSeed, quickTest, standardizeMode, dpHoldSamples, mat2str(channels), cfg.trainStride, cfg.maxEpoch);
emit(fid, "クラス: %s\n", strjoin(classes, ", "));
for e = 1:size(exps, 1)
    name = exps{e, 1};
    Te = T(T.Exp == name, :);
    emit(fid, "\n== %s ==\n", name);
    emit(fid, "  全体の正解率: %.1f%% (%d窓)\n", 100 * mean(Te.Correct), height(Te));
    rec = nan(1, numel(classes));
    for c = 1:numel(classes)
        m = Te.TrueRegime == classes(c);
        if any(m), rec(c) = 100 * mean(Te.Correct(m)); end
        emit(fid, "    %-11s: %5.1f%%\n", classes(c), rec(c));
    end
    emit(fid, "  流動様式ごとの平均 (クラス間の重みをそろえた正解率): %.1f%%\n", mean(rec, "omitnan"));
    % 条件が1対1に対応していない状況の判別力: 学習に同じ名目流量が無かった条件だけの正解率
    for sv = [true false]
        m = Te.SeenCondition == sv;
        if any(m)
            if sv, lbl = "同じ名目流量が学習にもあった条件 (L1G3, L3G3 など)"; else, lbl = "同じ名目流量が学習に無かった条件"; end
            emit(fid, "  %s: %.1f%% (%d条件, %d窓)\n", lbl, 100 * mean(Te.Correct(m)), ...
                numel(unique(Te.Condition(m) + "@" + Te.TestSet(m))), sum(m));
        end
    end
    for d = unique(Te.TestSet, "stable")'
        m = Te.TestSet == d;
        emit(fid, "  テストの日 %s: %.1f%% (%d窓)\n", d, 100 * mean(Te.Correct(m)), sum(m));
    end
    emit(fid, "  条件ごと:\n");
    for cnd = unique(Te.Condition + "@" + Te.TestSet, "stable")'
        parts = split(cnd, "@");
        m = Te.Condition == parts(1) & Te.TestSet == parts(2);
        share = strings(1, numel(classes));
        for c = 1:numel(classes), share(c) = sprintf("%s=%.0f", classes(c), 100 * mean(Te.Predicted(m) == classes(c))); end
        emit(fid, "    %-9s %-9s %-10s 正解率 %5.1f%%  予測先[%%]: %s\n", parts(2), parts(1), Te.TrueRegime(find(m, 1)), 100 * mean(Te.Correct(m)), strjoin(share, " "));
    end
    fig = figure("Visible", "off");
    confusionchart(categorical(Te.TrueRegime, classes), categorical(Te.Predicted, classes), "RowSummary", "row-normalized");
    title(strrep(name, "_", " ") + " (" + tag + ", seed " + runSeed + ")");
    exportgraphics(fig, fullfile(outDir, "confusion_" + name + ".png"));
end
fclose(fid);
pc = groupsummary(T, ["Exp", "TestSet", "Condition", "TrueRegime"], "mean", "Correct");
pc.AccuracyPercent = 100 * pc.mean_Correct;
writetable(pc, fullfile(outDir, "perCondition.csv"));
type(fullfile(outDir, "summary.txt"));
fprintf("保存しました: %s\n", outDir);

%% ---- ローカル関数 ----
function S = loadFiltered(date, conds, labs, corrs, cfg, dpHold)
    % 使う流動様式の条件だけを読み込む
    keep = false(size(conds));
    for i = 1:numel(conds)
        keep(i) = ismember(string(RawDataCreatorWave.correctFlowRegime(conds(i))), cfg.regimes);
    end
    S = loadWaveSeries(date, conds(keep), labs(keep), corrs(keep), cfg.freq, dpHold);
end

function describe(name, S)
    fprintf("%s: %d条件 (", name, numel(S));
    for r = ["Stratified", "Plug", "Slug"]
        fprintf("%s %d ", r, sum([S.regime] == r));
    end
    fprintf("), 差圧の平均 %.1f kPa\n", mean(arrayfun(@(s) mean(s.dp), S)));
end

function [X, Y] = buildSet(S, cfg, stride)
    % 条件ごとに窓の数をそろえる (記録の全体から等間隔に選ぶ)
    counts = arrayfun(@(s) numWindows(numel(s.vf), cfg.dataWidth, stride), S);
    nPer = min(counts);
    X = {}; Y = strings(0, 1);
    for i = 1:numel(S)
        W = makeWindows(S(i).vf, S(i).dp, cfg.dataWidth, stride);
        sel = round(linspace(1, numel(W), nPer));
        X = [X; cellfun(@(w) w(cfg.channels, :), W(sel), "UniformOutput", false)]; %#ok<AGROW>
        Y = [Y; repmat(S(i).regime, nPer, 1)]; %#ok<AGROW>
    end
end

function [mu, sg] = channelStats(X)
    A = cat(2, X{:});
    mu = mean(A, 2); sg = std(A, 0, 2); sg(sg < eps) = 1;
end

function T = runExperiment(name, trainS, testS, cfg, outDir)
    rng(cfg.seed);
    classes = sort(cfg.regimes);

    % 検証 (学習を止める判断) 用に, 各流動様式から1条件ずつ丸ごと外す (同じ条件の窓を検証に混ぜない)
    valNames = strings(1, 0);
    for r = classes
        names = unique([trainS([trainS.regime] == r).cond]);
        valNames(end+1) = names(randi(numel(names))); %#ok<AGROW>
    end
    isVal = ismember([trainS.cond], valNames);
    fprintf("学習の条件: %s\n検証の条件: %s\n", strjoin(unique([trainS(~isVal).cond]), ", "), strjoin(valNames, ", "));

    [Xtr, Ytr] = buildSet(trainS(~isVal), cfg, cfg.trainStride);
    [Xva, Yva] = buildSet(trainS(isVal), cfg, cfg.trainStride);

    % テストの窓
    nTest = numel(testS);
    Wt = cell(nTest, 1); starts = cell(nTest, 1);
    for i = 1:nTest
        [W, starts{i}] = makeWindows(testS(i).vf, testS(i).dp, cfg.dataWidth, cfg.testStride);
        Wt{i} = cellfun(@(w) w(cfg.channels, :), W, "UniformOutput", false);
    end

    % 標準化
    [mu, sg] = channelStats(Xtr);
    if cfg.standardizeMode == "ownYear"
        [muT, sgT] = channelStats(vertcat(Wt{:}));
    else
        muT = mu; sgT = sg;
    end
    std1 = @(c, m, s) cellfun(@(x) (x - m) ./ s, c, "UniformOutput", false);
    Xtr = std1(Xtr, mu, sg); Xva = std1(Xva, mu, sg);
    fprintf("標準化 (学習): 平均 %s, 標準偏差 %s / (テスト): 平均 %s, 標準偏差 %s\n", mat2str(mu', 4), mat2str(sg', 4), mat2str(muT', 4), mat2str(sgT', 4));

    % 学習
    layers = [sequenceInputLayer(numel(cfg.channels), "Name", "Seq")
              bilstmLayer(cfg.hidden, "OutputMode", "last", "Name", "biLSTM")
              fullyConnectedLayer(numel(classes), "Name", "fc")
              softmaxLayer("Name", "softmax")];
    net = trainBiLSTM(dlnetwork(layers), toArray(Xtr), Ytr, toArray(Xva), Yva, classes, cfg.learnRate, cfg.maxEpoch, cfg.batchSize, cfg.patience);
    save(fullfile(outDir, name + "_net.mat"), "net", "classes", "mu", "sg", "muT", "sgT");

    % テスト
    Ts = cell(nTest, 1);
    for i = 1:nTest
        P = predictProbabilities(net, std1(Wt{i}, muT, sgT), classes);
        [~, k] = max(P, [], 2);
        pred = classes(k); pred = pred(:);
        n = numel(pred);
        Ti = table(repmat(string(name), n, 1), repmat(testS(i).day, n, 1), repmat(testS(i).cond, n, 1), repmat(testS(i).regime, n, 1), ...
            (starts{i} - 1) / cfg.freq, pred, ...
            'VariableNames', {'Exp', 'TestSet', 'Condition', 'TrueRegime', 'WindowStartSec', 'Predicted'});
        for c = 1:numel(classes), Ti.("P_" + classes(c)) = P(:, c); end
        Ti.Correct = Ti.Predicted == Ti.TrueRegime;
        % 同じ名目流量の条件が学習の年にもあったか (あれば「運転点を覚えている」だけでも当たりうる)
        Ti.SeenCondition = repmat(ismember(testS(i).cond, [trainS(~isVal).cond]), n, 1);  % 検証用に外した条件は, 学習には使っていないので含めない
        Ts{i} = Ti;
        fprintf("  %s %-9s (%s): 正解率 %.1f%%\n", testS(i).day, testS(i).cond, testS(i).regime, 100 * mean(Ti.Correct));
    end
    T = vertcat(Ts{:});
    fprintf("%s 全体: %.1f%%\n", name, 100 * mean(T.Correct));
end

function emit(fid, varargin)
    s = sprintf(varargin{:});
    fprintf("%s", s);
    fprintf(fid, "%s", s);
end
