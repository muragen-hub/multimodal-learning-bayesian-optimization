%% runShapDemo.m
% SHAP (モダリティ単位) の動作確認用スクリプト.
%
% このリポジトリには実験の生データ(resources/data/)が含まれていないため,
% 学習済みの本物のネットワークを使って実行することはできない.
% そこで, 疑似データで小さなマルチモーダルネットワーク(CapWave/DiffWave/FeatureData
% の3branch)を学習し, computeModalityShapley.m / ShapDisplayer.m が正しく
% 動作すること・シャープレイ値の性質(寄与度の合計 = 予測値 - 平均予測値)が
% 成り立つことを確認する.
%
% ネットワーク構造そのものは LayerSettingCreatorTwo.createMultimodalLayerGraph
% (06_training_settings) を再利用している. 学習ループはこのデモ専用の
% 最小実装であり, 07_training/TrainActivatorTwo.customActivateMultimodal
% とは別物(そちらの学習ループを変更・依存するものではない).

clc; clear; close all hidden;
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(repoRoot));

rng(0);

%% 1. 疑似データ生成 (クラスごとに層化して train/test に分割する)
flowRegimes = ["Stratified" "Bubbly" "Slug" "Plug" "Annular"];
numClasses = numel(flowRegimes);
samplesPerClass = 16;
seqLen = 20;
featureDim = 4;

N = numClasses * samplesPerClass;
allCap  = cell(N,1);
allDiff = cell(N,1);
allFeat = zeros(N, featureDim);
labelStr = strings(N,1);

idx = 1;
for c = 1:numClasses
    classOffset = c; % クラスごとに平均値をずらし, 学習可能な疑似データにする
    for s = 1:samplesPerClass
        allCap{idx}    = classOffset + 0.3*randn(seqLen,1);
        allDiff{idx}   = -classOffset + 0.3*randn(seqLen,1);
        allFeat(idx,:) = classOffset + 0.2*randn(1,featureDim);
        labelStr(idx)  = flowRegimes(c);
        idx = idx + 1;
    end
end
label = categorical(labelStr, flowRegimes);

trainIdx = [];
testIdx = [];
for c = 1:numClasses
    classIdx = find(labelStr == flowRegimes(c))';
    classIdx = classIdx(randperm(numel(classIdx)));
    nTrainC = round(0.75*numel(classIdx));
    trainIdx = [trainIdx, classIdx(1:nTrainC)]; %#ok<AGROW>
    testIdx  = [testIdx, classIdx(nTrainC+1:end)]; %#ok<AGROW>
end

train = TrainTestDataTwo(allCap(trainIdx), allDiff(trainIdx), allFeat(trainIdx,:), ...
    label(trainIdx), seqLen, string(trainIdx), labelStr(trainIdx).');
test  = TrainTestDataTwo(allCap(testIdx), allDiff(testIdx), allFeat(testIdx,:), ...
    label(testIdx), seqLen, string(testIdx), labelStr(testIdx).');

%% 2. ネットワーク構築 (既存の LayerSettingCreatorTwo を再利用)
layerSettingCreator = LayerSettingCreatorTwo(train, test);
lgraph = layerSettingCreator.createMultimodalLayerGraph(1, 1, featureDim, 8, 8);
net = dlnetwork(lgraph);
disp("net.InputNames = " + strjoin(net.InputNames, ", "));

%% 3. 簡易学習ループ (このデモ専用. CBT/CB フォーマットで動作確認するための最小実装)
classes = categories(label);
numEpochs = 40;
miniBatchSize = 8;
learnRate = 0.01;
trailingAvg = []; trailingAvgSq = []; iteration = 0;

for epoch = 1:numEpochs
    shuffleIdx = trainIdx(randperm(numel(trainIdx)));
    for b = 1:miniBatchSize:numel(shuffleIdx)
        batchIdx = shuffleIdx(b:min(b+miniBatchSize-1, numel(shuffleIdx)));
        [cap_dl, diff_dl, feat_dl] = localBatchToDlarray(allCap(batchIdx), allDiff(batchIdx), allFeat(batchIdx,:));
        T_onehot = onehotencode(reshape(label(batchIdx), 1, []), 1, 'ClassNames', classes);
        T_dl = dlarray(T_onehot, 'CB');

        iteration = iteration + 1;
        [~, gradients] = dlfeval(@localModelGradients, net, cap_dl, diff_dl, feat_dl, T_dl);
        [net, trailingAvg, trailingAvgSq] = adamupdate(net, gradients, trailingAvg, trailingAvgSq, iteration, learnRate);
    end
end

%% 4. 学習の健全性確認 (疑似データでの分類精度. 実データでの精度評価ではない)
[cap_dl, diff_dl, feat_dl] = localBatchToDlarray(allCap(testIdx), allDiff(testIdx), allFeat(testIdx,:));
Ypred = predict(net, cap_dl, diff_dl, feat_dl);
[~, predIdx] = max(extractdata(Ypred), [], 1);
predictedLabel = categorical(classes(predIdx));
testAcc = mean(predictedLabel(:) == label(testIdx));
fprintf("[疑似データでの健全性確認] テスト精度: %.3f (学習ループ自体が機能していることの確認用)\n", testAcc);

%% 5. SHAP (モダリティ単位) の計算
forwardFcn = @(capBatch, diffBatch, featBatch) localForwardFcn(capBatch, diffBatch, featBatch, net);

targetSampleIdx = testIdx(1);
targetClass = label(targetSampleIdx);
targetClassIdx = find(classes == targetClass);

bgIdx = trainIdx(randperm(numel(trainIdx), min(30, numel(trainIdx))));

explainer = computeModalityShapley(allCap, allDiff, allFeat, forwardFcn, targetClassIdx, bgIdx, targetSampleIdx);

fprintf("\n=== 対象サンプル (テストデータ index=%d) ===\n", targetSampleIdx);
fprintf("真のラベル: %s\n", string(targetClass));
disp("=== モダリティ別 Shapley値 (対象クラス: " + string(targetClass) + ") ===")
disp(explainer.Shapley)
fprintf("Intercept + sum(Shapley) = %.5f (= BlackboxFitted %.5f であるはず)\n", ...
    explainer.Intercept + sum(explainer.Shapley.Value), explainer.BlackboxFitted);

%% 6. 可視化
displayer = ShapDisplayer();
displayer.displaySingleQuery(explainer, "shap_demo");

%% 7. 複数サンプルでの集計 (同一流動様式のテストサンプルを数件まとめて平均寄与度を見る)
sameClassTestIdx = testIdx(label(testIdx) == targetClass);
explainerArray = cell(1, numel(sameClassTestIdx));
for i = 1:numel(sameClassTestIdx)
    explainerArray{i} = computeModalityShapley(allCap, allDiff, allFeat, forwardFcn, ...
        targetClassIdx, bgIdx, sameClassTestIdx(i));
end
meanAbsShap = displayer.displayAggregated(explainerArray, "shap_demo");
fprintf("\n=== %s クラスの平均|Shapley値| (n=%d) ===\n", string(targetClass), numel(sameClassTestIdx));
for m = 1:numel(displayer.modalityNames)
    fprintf("  %-12s: %.5f\n", displayer.modalityNames(m), meanAbsShap(m));
end

%% ローカル関数 (このデモ専用のCBT/CBフォーマット変換とforward呼び出し)
function [cap_dl, diff_dl, feat_dl] = localBatchToDlarray(capBatch, diffBatch, featBatch)
    n = numel(capBatch);
    seqLen = numel(capBatch{1}); %#ok<NASGU>
    capArr  = zeros(1, n, numel(capBatch{1}));
    diffArr = zeros(1, n, numel(diffBatch{1}));
    for i = 1:n
        capArr(1,i,:)  = capBatch{i}(:)';
        diffArr(1,i,:) = diffBatch{i}(:)';
    end
    cap_dl  = dlarray(capArr,  'CBT');
    diff_dl = dlarray(diffArr, 'CBT');
    feat_dl = dlarray(featBatch', 'CB');
end

function [loss, gradients] = localModelGradients(net, cap_dl, diff_dl, feat_dl, T_dl)
    Y = forward(net, cap_dl, diff_dl, feat_dl);
    loss = crossentropy(Y, T_dl);
    gradients = dlgradient(loss, net.Learnables);
end

function scoresMatrix = localForwardFcn(capBatch, diffBatch, featBatch, net)
    [cap_dl, diff_dl, feat_dl] = localBatchToDlarray(capBatch, diffBatch, featBatch);
    Y = predict(net, cap_dl, diff_dl, feat_dl);
    scoresMatrix = extractdata(Y)'; % 行=サンプル, 列=クラス
end
