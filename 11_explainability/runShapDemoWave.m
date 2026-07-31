%% runShapDemoWave.m
% SHAP (Waveパイプライン: VF/Pr 2ch 単一biLSTM) の動作確認用スクリプト.
%
% このリポジトリには実験の生データ(resources/data/)も学習済みネットワーク(nets/)も
% 含まれていないため, 学習済みの本物のネットワークを使って実行することはできない.
% そこで, 疑似データで deepLearning_wave_multimodalClassification.mlx と同型の
% 小さなネットワーク(sequenceInputLayer(2) -> bilstmLayer -> fc -> softmax)を学習し,
% computeShapleyChannelLevel.m / computeShapleyPhysicalStats.m / computeClassWiseShapley.m
% が正しく動作すること・Shapley値の性質(寄与度の合計 = 予測値 - 平均予測値)が
% 成り立つことを確認する.
%
% 疑似データの各クラスの目標統計量(VF_mean/VF_std/Pr_std/Pr_r=diffStd/std)は
% SHAP関数設計メモの「仮説から導いた予測」表を単純化して割り当てている. 実データでの
% 結論を先取りするものではなく, あくまで再構成ロジック(affineMatchMeanStd.m /
% findPrShapeDonor.m)を含むパイプライン全体が動くことの確認が目的.
%
% 実データでの結線方法(nets/に本物のTrainResultを配置した後):
%   result = load('nets/<netSaveDirectory>/<netSaveName>.mat').result; % TrainResult
%   net = result.net{1};  % result.net, result.nets ではない点に注意
%   forwardFcn = @(vfBatch, prBatch) ...
%       extractdata(predict(net, wavesToCTB(vfBatch, prBatch), Outputs=["softmax"]))';
%   allVF/allPr は test.data (または train.data) の1行目・2行目をcellごとに分けて用意する.

clc; clear; close all hidden;
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(repoRoot));

rng(0);

%% 1. 疑似データ生成 (クラスごとに層化して train/test に分割する)
flowRegimes = ["Stratified" "Bubbly" "Slug" "Plug" "Annular"];
numClasses = numel(flowRegimes);
samplesPerClass = 24;
seqLen = 60;

% クラスごとの目標統計量(設計メモの予測表を単純化した数値プロキシ).
% Pr_r = Pr_diffStd / Pr_std (スケール非依存の"速さ"形状パラメータ).
% VF_mean VF_std Pr_mean Pr_std Pr_r
classTargets = [ ...
    0.50   0.03   0.50   0.03   0.30;  % Stratified: 静的な相分布, 界面は滑らか
    0.20   0.03   0.50   0.03   0.30;  % Bubbly: 小気泡が平均化される
    0.70   0.15   0.50   0.15   1.10;  % Slug: 振幅・速さともに最大
    0.65   0.15   0.50   0.08   0.60;  % Plug: 間欠的だが運動量変化は穏やか
    0.85   0.07   0.50   0.05   0.90]; % Annular: 振幅は小さいが高周波リップルでr が高め

% 形状ドナープール: 平滑化の度合いを変えた疑似波形(diffStd/std比にバリエーションを持たせる)
numDonors = 300;
donorPool = cell(numDonors, 1);
for i = 1:numDonors
    smoothWin = randi([1 12]);
    raw = randn(seqLen + smoothWin - 1, 1);
    donorPool{i} = movmean(raw, smoothWin);
    donorPool{i} = donorPool{i}(1:seqLen);
end
donorR = precomputePrShapeRatios(donorPool);

N = numClasses * samplesPerClass;
allVF  = cell(N,1);
allPr  = cell(N,1);
allData = cell(N,1);
labelStr = strings(N,1);

idx = 1;
for c = 1:numClasses
    target = classTargets(c, :);
    for s = 1:samplesPerClass
        jitter = 1 + 0.1*randn(1,5);
        vfMean = target(1); vfStd = max(target(2)*jitter(2), 1e-3);
        prMean = target(3); prStd = max(target(4)*jitter(4), 1e-3);
        prR    = max(target(5)*jitter(5), 1e-3);
        prDiffStd = prR * prStd;

        prDonorIdx = findPrShapeDonor(donorR, prDiffStd, prStd);
        vfDonorIdx = randi(numDonors);

        vfWave = affineMatchMeanStd(donorPool{vfDonorIdx}, vfMean, vfStd);
        prWave = affineMatchMeanStd(donorPool{prDonorIdx}, prMean, prStd);

        allVF{idx} = vfWave;
        allPr{idx} = prWave;
        allData{idx} = [vfWave'; prWave'];
        labelStr(idx) = flowRegimes(c);
        idx = idx + 1;
    end
end
label = categorical(labelStr, flowRegimes);
classes = categories(label);

trainIdx = [];
testIdx = [];
for c = 1:numClasses
    classIdx = find(labelStr == flowRegimes(c))';
    classIdx = classIdx(randperm(numel(classIdx)));
    nTrainC = round(0.75*numel(classIdx));
    trainIdx = [trainIdx, classIdx(1:nTrainC)]; %#ok<AGROW>
    testIdx  = [testIdx, classIdx(nTrainC+1:end)]; %#ok<AGROW>
end

train = TrainTestDataWave(allData(trainIdx), label(trainIdx), numel(trainIdx), ...
    string(trainIdx), labelStr(trainIdx).');
test  = TrainTestDataWave(allData(testIdx), label(testIdx), numel(testIdx), ...
    string(testIdx), labelStr(testIdx).');

%% 2. ネットワーク構築 (deepLearning_wave_multimodalClassification.mlx と同型)
layerSettingCreator = LayerSettingCreatorWave(train, test);
layerSetting = layerSettingCreator.createSingleLSTMLayerForCustomLossFunc(2, 16);
net = dlnetwork(layerSetting);

%% 3. 簡易学習ループ (このデモ専用. wavesToCTB.m で本番と同じCTB変換を使う)
numEpochs = 60;
miniBatchSize = 8;
learnRate = 0.01;
trailingAvg = []; trailingAvgSq = []; iteration = 0;

for epoch = 1:numEpochs
    shuffleIdx = trainIdx(randperm(numel(trainIdx)));
    for b = 1:miniBatchSize:numel(shuffleIdx)
        batchIdx = shuffleIdx(b:min(b+miniBatchSize-1, numel(shuffleIdx)));
        dlX = wavesToCTB(allVF(batchIdx), allPr(batchIdx));
        T_onehot = onehotencode(reshape(label(batchIdx), 1, []), 1, 'ClassNames', classes);
        T_dl = dlarray(T_onehot, 'CB');

        iteration = iteration + 1;
        [~, gradients] = dlfeval(@localModelGradients, net, dlX, T_dl);
        [net, trailingAvg, trailingAvgSq] = adamupdate(net, gradients, trailingAvg, trailingAvgSq, iteration, learnRate);
    end
end

%% 4. 学習の健全性確認 (疑似データでの分類精度. 実データでの精度評価ではない)
dlXTest = wavesToCTB(allVF(testIdx), allPr(testIdx));
Ypred = predict(net, dlXTest, Outputs=["softmax"]);
[~, predIdx] = max(extractdata(Ypred), [], 1);
predictedLabel = categorical(classes(predIdx));
testAcc = mean(predictedLabel(:) == label(testIdx));
fprintf("[疑似データでの健全性確認] テスト精度: %.3f (学習ループ自体が機能していることの確認用)\n", testAcc);

%% 5. SHAP (チャンネル単位 / 統計量ベース) をクラスごとに計算
forwardFcn = @(vfBatch, prBatch) extractdata(predict(net, wavesToCTB(vfBatch, prBatch), Outputs=["softmax"]))';

bgIdx = trainIdx(randperm(numel(trainIdx), min(15, numel(trainIdx))));

fprintf("\n=== ① チャンネル単位SHAP (VF波形 / Pr波形) をクラスごとに計算中 ===\n");
channelShapleyFcn = @(targetClassIdx, queryIdx) computeShapleyChannelLevel( ...
    allVF, allPr, forwardFcn, targetClassIdx, bgIdx, queryIdx);
meanAbsShapChannel = computeClassWiseShapley(channelShapleyFcn, 2, label, categorical(classes), bgIdx, ...
    'MaxQueriesPerClass', 3);

disp(array2table(meanAbsShapChannel, 'VariableNames', {'VF','Pr'}, 'RowNames', cellstr(classes)))

fprintf("\n=== ③ 統計量ベースSHAP (VF_mean/VF_std/Pr_mean/Pr_std/Pr_diffStd) をクラスごとに計算中 ===\n");
statsShapleyFcn = @(targetClassIdx, queryIdx) computeShapleyPhysicalStats( ...
    allVF, allPr, forwardFcn, targetClassIdx, bgIdx, queryIdx);
meanAbsShapStats = computeClassWiseShapley(statsShapleyFcn, 5, label, categorical(classes), bgIdx, ...
    'MaxQueriesPerClass', 2);

statFeatureNames = ["VF_mean" "VF_std" "Pr_mean" "Pr_std" "Pr_diffStd"];
disp(array2table(meanAbsShapStats, 'VariableNames', statFeatureNames, 'RowNames', cellstr(classes)))

%% 6. 可視化
ShapDisplayerWave.displayClassWiseHeatmap(meanAbsShapChannel, ["VF" "Pr"], string(classes), "shap_demo_wave", ...
    'fileName', "ShapleyValues_ChannelLevel_ClassWise", 'figTitle', "チャンネル単位 クラス別 平均|Shapley値|");
ShapDisplayerWave.displayClassWiseHeatmap(meanAbsShapStats, statFeatureNames, string(classes), "shap_demo_wave", ...
    'fileName', "ShapleyValues_PhysicalStats_ClassWise", 'figTitle', "統計量ベース クラス別 平均|Shapley値|");

%% ローカル関数
function [loss, gradients] = localModelGradients(net, dlX, T_dl)
    Y = forward(net, dlX);
    loss = crossentropy(Y, T_dl);
    gradients = dlgradient(loss, net.Learnables);
end
