%% deepLearning_wave_2026_conditionCV.m
% Step 1: 2026/11/20 のデータ (20条件, 流動様式ごとに5条件) で, マルチモーダル biLSTM
% (静電容量→ボイド率 と ベンチュリ差圧 の2ch, 4秒 = 400点) を「条件単位の5分割交差検証」で評価する.
%
% 目的: 層状流 (L0.3) の記録には 8〜10秒ごとに液の橋 (スラグ) が来る. 20秒すべてを「層状流」として
%       学習・テストし, テストの窓を「液の橋を含む / 届きかけの波を含む / 含まない」に分けて正解率を比べる.
%       → 遷移を含む窓で正解率が下がることを示す.
%
% 既存の deepLearning_wave_conditionHoldout.m との違い:
%   (1) 標準化の平均・標準偏差は訓練データだけから求め, テストにも同じ値を使う
%       (cellInputStandardizeWave は訓練とテストを別々に標準化していた).
%   (2) 早期終了の判断にテストデータを使わない (訓練データの一部を検証用に回す).
%   (3) 訓練とテストで条件の数が違っても正しく扱えるように, 窓づくりをこのスクリプトの中で行う
%       (TrainTestDataCreatorWave は訓練の条件数でテストも数えるため, テスト条件が切り捨てられていた).
%   (4) 学習ループもこのスクリプトの中に書いた (公開リポジトリには preprocessFlowData, thresholdL2Norm,
%       stopIfAccuracyNotImproving が無く, TrainActivatorWave がそのままでは動かないため).
%       ネットワーク構成・学習率・ミニバッチ・勾配クリップは元と同じ. 検証の損失が最小の時点を使う.
%
% 使い方 (MATLAB, リポジトリのルートで):
%   runSeed = 1; deepLearning_wave_2026_conditionCV      % 乱数の種を変えて 1,2,3 と回す
%   試しに速く回すとき: quickTest = true; runSeed = 1; deepLearning_wave_2026_conditionCV
%
% 出力: results/step1_conditionCV/<日時>_seed<種>/
%   windows.csv      … テストの全窓 (分割, 条件, 正解, 予測, 各クラスの確率, 液の橋の判定)
%   perCondition.csv … 条件ごとの正解率
%   stratifiedByBridge.csv … 層状流の窓を液の橋の有無で分けた正解率
%   summary.txt, confusion.png, stratified_timeline_<条件>.png

clc;
clearvars -except runSeed quickTest;
close all hidden;
addpath(genpath(pwd));

if ~exist("runSeed", "var"), runSeed = 1; end
if ~exist("quickTest", "var"), quickTest = false; end

%% 0. 設定
date = "20261120";
conds = Conditions.c20_2026;
labs = Labels.c20_2026_normal;
corr = CorrectConditions.c20_2026_liquidChange;
measuredFreq = 100;

dataWidth = 400;        % 4秒
trainStride = 1;        % 訓練の窓をずらす幅 [点]
testStride = 10;        % テストの窓をずらす幅 [点] (0.1秒ごと. 時間変化を見るには十分)
valFraction = 0.1;      % 訓練の窓のうち検証 (学習の監視) に回す割合

% 液の橋の判定 (research_notes/遷移区間のラベル付け方法 の暫定ルール. 感度は別途確認する)
bridgeThreshold = 311e-15;   % [F] 満管 (329 fF) の約0.9以上 → 液の橋が管をふさいだ
partialThreshold = 275e-15;  % [F] 満管の約0.7以上 → 届きかけの波・擬似スラグ
minSamples = 5;              % 0.05秒以上続いたら数える

% 学習の設定 (学習率・エポック数・ミニバッチ・隠れ層は元のライブスクリプトと同じ)
initialLearnRate = 0.001;
maxEpoch = 30;
miniBatchSize = 64;
hiddenUnitSize = 320;
patienceEpochs = 5;     % 検証の損失がこの回数続けて下がらなければ終了し, 最も良かった時点のネットワークを使う
if quickTest
    maxEpoch = 2; trainStride = 20; testStride = 50;
end

rng(runSeed);
outDir = fullfile("results", "step1_conditionCV", string(datetime("now", "Format", "yyyyMMdd_HHmm")) + "_seed" + runSeed);
mkdir(outDir);

%% 1. データの取り込みと前処理 (20条件まとめて)
dc = RawDataCreatorWave();
vfRaw = dc.createVF(date, measuredFreq, conds, labs, true, corr);
prRaw = dc.createPr(date, measuredFreq, conds, labs, true, corr);
rawAll = RawAllDataBeforeFormatWave([vfRaw, prRaw]);
pp = PreProcessorBeforeFormatWave({@intervalUniformerWave, @correctWithCapacitanceBaseWave});
vf = pp.process(vfRaw, rawAll);
pr = pp.process(prRaw, rawAll);

[gasRef, liqRef] = resolveCapacitanceCalibration(date, corr(1));
fprintf("静電容量の基準: 気相 %.1f fF, 液相 %.1f fF\n", gasRef*1e15, liqRef*1e15);

nCond = numel(conds);
series = struct("cond", {}, "regime", {}, "vf", {}, "dp", {}, "cap", {});
for i = 1:nCond
    v = vf.modifiedRawDataWave(i).WaveDataCell{1};
    p = pr.modifiedRawDataWave(i).WaveDataCell{1};
    n = min(numel(v), numel(p));
    v = v(1:n); p = p(1:n);
    ok = ~isnan(v) & ~isnan(p);
    v = v(ok); p = p(ok);
    series(i).cond = string(vf.modifiedRawDataWave(i).conditions{1});
    series(i).regime = string(vf.modifiedRawDataWave(i).FlowRegimeLabel);
    series(i).vf = v(:);
    series(i).dp = p(:);
    series(i).cap = liqRef - v(:) * (liqRef - gasRef);   % ボイド率から静電容量に戻す (液の橋の判定用)
    assert(series(i).cond == conds(i), "条件の並びがずれています: %s", series(i).cond);
end
regimes = unique([series.regime], "stable");
fprintf("流動様式: %s\n", strjoin(regimes, ", "));

%% 2. 分割 (各流動様式の k 番目の条件を分割 k のテストにする → 20条件すべてが1回ずつテストされる)
fold = zeros(1, nCond);
for r = 1:numel(regimes)
    idx = find([series.regime] == regimes(r));
    fold(idx) = 1:numel(idx);
end
nFold = max(fold);

%% 3. 分割ごとに学習とテスト
allRows = {};
for k = 1:nFold
    testIdx = find(fold == k);
    trainIdx = find(fold ~= k);
    fprintf("\n=== 分割 %d / %d: テスト条件 = %s ===\n", k, nFold, strjoin([series(testIdx).cond], ", "));

    % 3-1. 訓練の窓 (各条件の窓数をそろえる: 元の実装と同じ)
    [Xtr, Ytr] = deal({}, strings(0, 1));
    perCond = arrayfun(@(i) numWindows(numel(series(i).vf), dataWidth, trainStride), trainIdx);
    nPer = min(perCond);
    for i = trainIdx
        W = makeWindows(series(i).vf, series(i).dp, dataWidth, trainStride);
        W = W(1:nPer);
        Xtr = [Xtr; W]; %#ok<AGROW>
        Ytr = [Ytr; repmat(series(i).regime, nPer, 1)]; %#ok<AGROW>
    end

    % 3-2. 標準化 (訓練データだけから平均・標準偏差を求める)
    allTr = cat(2, Xtr{:});                    % [2 x (窓数*400)]
    mu = mean(allTr, 2); sg = std(allTr, 0, 2); sg(sg < eps) = 1;
    standardize = @(c) cellfun(@(x) (x - mu) ./ sg, c, "UniformOutput", false);
    Xtr = standardize(Xtr);

    % 3-3. 検証用 (学習の監視・早期終了用. テストデータは使わない)
    perm = randperm(numel(Xtr));
    nVal = round(valFraction * numel(Xtr));
    valSel = perm(1:nVal); trSel = perm(nVal+1:end);
    classes = unique(Ytr)';                     % アルファベット順: Bubbly, Plug, Slug, Stratified

    % 3-4. 学習 (元のライブスクリプトと同じネットワーク構成: biLSTM(320, 最後の出力) → 全結合 → softmax)
    layers = [sequenceInputLayer(2, "Name", "Seq")
              bilstmLayer(hiddenUnitSize, "OutputMode", "last", "Name", "biLSTM")
              fullyConnectedLayer(numel(classes), "Name", "fc")
              softmaxLayer("Name", "softmax")];
    net = trainBiLSTM(dlnetwork(layers), toArray(Xtr(trSel)), Ytr(trSel), toArray(Xtr(valSel)), Ytr(valSel), ...
        classes, initialLearnRate, maxEpoch, miniBatchSize, patienceEpochs);
    save(fullfile(outDir, "net_fold" + k + ".mat"), "net", "classes", "mu", "sg");

    % 3-5. テスト (条件ごとに, 窓を時間順に予測して確率を保存)
    for i = testIdx
        [W, starts] = makeWindows(series(i).vf, series(i).dp, dataWidth, testStride);
        Ws = standardize(W);
        P = predictProbabilities(net, Ws, classes);
        [~, kmax] = max(P, [], 2);
        pred = classes(kmax);
        for w = 1:numel(W)
            seg = series(i).cap(starts(w):starts(w) + dataWidth - 1);
            nBridge = sum(seg >= bridgeThreshold);
            nPartial = sum(seg >= partialThreshold & seg < bridgeThreshold);
            if nBridge >= minSamples
                bridgeClass = "bridge";        % 液の橋 (管をふさいだ) を含む
            elseif nPartial >= minSamples
                bridgeClass = "partial";       % 届きかけの波・擬似スラグを含む
            else
                bridgeClass = "none";
            end
            allRows(end+1, :) = {runSeed, k, series(i).cond, series(i).regime, (starts(w) - 1) / measuredFreq, ...
                pred(w), P(w, :), nBridge / dataWidth, nPartial / dataWidth, bridgeClass}; %#ok<SAGROW>
        end
        fprintf("  %-9s (%s): 正解率 %.1f%%\n", series(i).cond, series(i).regime, 100 * mean(pred == series(i).regime));
    end
end

%% 4. 集計と保存
probs = cell2mat(allRows(:, 7));
T = table(cell2mat(allRows(:, 1)), cell2mat(allRows(:, 2)), string(allRows(:, 3)), string(allRows(:, 4)), cell2mat(allRows(:, 5)), ...
    string(allRows(:, 6)), cell2mat(allRows(:, 8)), cell2mat(allRows(:, 9)), string(allRows(:, 10)), ...
    'VariableNames', {'Seed', 'Fold', 'Condition', 'TrueRegime', 'WindowStartSec', 'Predicted', 'BridgeFraction', 'PartialFraction', 'BridgeClass'});
for c = 1:numel(classes)
    T.("P_" + classes(c)) = probs(:, c);
end
T.Correct = T.Predicted == T.TrueRegime;
writetable(T, fullfile(outDir, "windows.csv"));

perCondition = groupsummary(T, ["Condition", "TrueRegime"], "mean", "Correct");
perCondition.AccuracyPercent = 100 * perCondition.mean_Correct;
writetable(perCondition, fullfile(outDir, "perCondition.csv"));
disp(perCondition(:, ["Condition", "TrueRegime", "GroupCount", "AccuracyPercent"]))

S = T(T.TrueRegime == "Stratified", :);
byBridge = groupsummary(S, "BridgeClass", "mean", "Correct");
byBridge.AccuracyPercent = 100 * byBridge.mean_Correct;
predShare = groupsummary(S, ["BridgeClass", "Predicted"]);
writetable(byBridge, fullfile(outDir, "stratifiedByBridge.csv"));
writetable(predShare, fullfile(outDir, "stratifiedPredictedByBridge.csv"));
disp(byBridge(:, ["BridgeClass", "GroupCount", "AccuracyPercent"]))

fid = fopen(fullfile(outDir, "summary.txt"), "w");
fprintf(fid, "seed=%d, quickTest=%d, maxEpoch=%d, trainStride=%d, testStride=%d\n", runSeed, quickTest, maxEpoch, trainStride, testStride);
fprintf(fid, "基準: 気相 %.1f fF, 液相 %.1f fF / 液の橋 >= %.0f fF, 届きかけ >= %.0f fF, %d点以上\n", gasRef*1e15, liqRef*1e15, bridgeThreshold*1e15, partialThreshold*1e15, minSamples);
fprintf(fid, "全体の正解率: %.2f%% (%d窓)\n", 100 * mean(T.Correct), height(T));
for r = regimes
    fprintf(fid, "  %s: %.2f%%\n", r, 100 * mean(T.Correct(T.TrueRegime == r)));
end
fprintf(fid, "層状流の窓 (液の橋の有無別):\n");
for j = 1:height(byBridge)
    fprintf(fid, "  %s: %.2f%% (%d窓)\n", byBridge.BridgeClass(j), byBridge.AccuracyPercent(j), byBridge.GroupCount(j));
end
fclose(fid);
type(fullfile(outDir, "summary.txt"))

fig = figure("Visible", "off");
confusionchart(categorical(T.TrueRegime), categorical(T.Predicted), "RowSummary", "row-normalized");
title("条件単位の5分割交差検証 (seed " + runSeed + ")");
exportgraphics(fig, fullfile(outDir, "confusion.png"));

% 層状流の各条件: 静電容量と「スラグ流」の確率の時間変化 (Step 3 の下見)
for i = find([series.regime] == "Stratified")
    Ti = T(T.Condition == series(i).cond, :);
    t = (0:numel(series(i).cap) - 1) / measuredFreq;
    fig = figure("Visible", "off", "Position", [100 100 900 420]);
    tiledlayout(2, 1);
    nexttile; plot(t, series(i).cap * 1e15); hold on;
    yline(bridgeThreshold * 1e15, "--r"); yline(partialThreshold * 1e15, ":r");
    ylabel("静電容量 [fF]"); title(series(i).cond + " (層状流ラベル)");
    nexttile; hold on;
    for c = 1:numel(classes)
        plot(Ti.WindowStartSec + dataWidth / measuredFreq / 2, Ti.("P_" + classes(c)), "DisplayName", classes(c));
    end
    ylim([0 1]); ylabel("確率 (窓の中央の時刻)"); xlabel("時間 [s]"); legend("Location", "eastoutside");
    exportgraphics(fig, fullfile(outDir, "stratified_timeline_" + series(i).cond + ".png"));
end
fprintf("保存しました: %s\n", outDir);

%% ---- ローカル関数 ----
function n = numWindows(len, width, stride)
    n = max(floor((len - width) / stride) + 1, 0);
end

function [W, starts] = makeWindows(vf, dp, width, stride)
    % 2ch の窓 {N x 1} を作る. 各要素は [2 x width] (1行目 = ボイド率, 2行目 = 差圧)
    n = numWindows(numel(vf), width, stride);
    starts = (0:n - 1)' * stride + 1;
    W = cell(n, 1);
    for j = 1:n
        s = starts(j);
        W{j} = [vf(s:s + width - 1)'; dp(s:s + width - 1)'];
    end
end

function X = toArray(W)
    % {N x 1} の [2 x W] 窓 → [2 x W x N] の single 配列
    X = single(cat(3, W{:}));
end

function P = predictProbabilities(net, W, classes)
    % 窓ごとの各クラスの確率 [N x クラス数]
    X = toArray(W);
    n = size(X, 3);
    P = zeros(n, numel(classes));
    batch = 512;
    for s = 1:batch:n
        idx = s:min(s + batch - 1, n);
        dlX = dlarray(X(:, :, idx), "CTB");
        if canUseGPU, dlX = gpuArray(dlX); end
        Y = predict(net, dlX);
        P(idx, :) = gather(extractdata(Y))';
    end
end

function bestNet = trainBiLSTM(net, Xtr, Ytr, Xval, Yval, classes, learnRate, maxEpoch, batchSize, patience)
    % Adam + 勾配クリップ (L2ノルム 1) で学習する. 検証の損失が最小の時点のネットワークを返す.
    Ttr = single(Ytr(:)' == classes(:));        % one-hot [クラス数 x N]
    Tval = single(Yval(:)' == classes(:));
    n = size(Xtr, 3);
    avgG = []; avgSqG = []; iter = 0;
    bestLoss = Inf; bestNet = net; noImprove = 0;
    for epoch = 1:maxEpoch
        order = randperm(n);
        for s = 1:batchSize:(n - batchSize + 1)
            idx = order(s:s + batchSize - 1);
            iter = iter + 1;
            dlX = dlarray(Xtr(:, :, idx), "CTB");
            T = Ttr(:, idx);
            if canUseGPU, dlX = gpuArray(dlX); T = gpuArray(T); end
            [~, grad] = dlfeval(@modelLoss, net, dlX, T);
            grad = dlupdate(@clipL2, grad);
            [net, avgG, avgSqG] = adamupdate(net, grad, avgG, avgSqG, iter, learnRate);
        end
        [valLoss, valAcc] = evaluateSet(net, Xval, Tval);
        fprintf("    エポック %2d: 検証の損失 %.4f, 検証の正解率 %.1f%%\n", epoch, valLoss, 100 * valAcc);
        if valLoss < bestLoss
            bestLoss = valLoss; bestNet = net; noImprove = 0;
        else
            noImprove = noImprove + 1;
            if noImprove >= patience, break; end
        end
    end
end

function [loss, grad] = modelLoss(net, dlX, T)
    Y = forward(net, dlX);
    loss = crossentropy(Y, T, "DataFormat", "CB");
    grad = dlgradient(loss, net.Learnables);
end

function g = clipL2(g)
    nrm = sqrt(sum(g.^2, "all"));
    if nrm > 1, g = g / nrm; end
end

function [loss, acc] = evaluateSet(net, X, T)
    n = size(X, 3); batch = 512; lossSum = 0; correct = 0;
    for s = 1:batch:n
        idx = s:min(s + batch - 1, n);
        dlX = dlarray(X(:, :, idx), "CTB");
        if canUseGPU, dlX = gpuArray(dlX); end
        Y = gather(extractdata(predict(net, dlX)));
        lossSum = lossSum + double(crossentropy(dlarray(Y, "CB"), dlarray(T(:, idx), "CB"))) * numel(idx);
        [~, p] = max(Y, [], 1); [~, t] = max(T(:, idx), [], 1);
        correct = correct + sum(p == t);
    end
    loss = lossSum / n; acc = correct / n;
end
