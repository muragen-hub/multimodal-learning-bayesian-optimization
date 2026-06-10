function val = optimizeModelTwo(params)
% =============================================
% optimizeModelTwo
% - ベイズ最適化用目的関数
% - 結果を1ファイルにまとめる (追記可能)
% =============================================

persistent resultPath iteration initialized

% --- 初回 or persistent が壊れた場合は再初期化 ---
if isempty(initialized) || ~initialized || isempty(resultPath)
    timestamp = datetime('now','Format','yyyyMMdd_HHmmss'); % ファイル名用
    saveDir = '/home/twophaseflow/deepLearningForMultiMeter/deepLearningForMultiMeter/File_MURATA_Flow_Regime';
    
    if ~exist(saveDir, 'dir')
        mkdir(saveDir);
    end
    
    % CSVファイル名を生成
    resultPath = fullfile(saveDir, ['bayesopt_results_' string(timestamp) '.csv']);
    iteration = 1;
    initialized = true;
    
    disp(['🔔 新しいベイズ最適化セッションを開始: ' resultPath]);
else
    iteration = iteration + 1;
end

% =============================================
% データ読み込み
% =============================================
load('trainDataInstance.mat', 'train');
load('testDataInstance.mat', 'test');

% --- マルチインプット用データ整形 ---
trainInput = {cell2mat(train.CapWaveData), cell2mat(train.DiffWaveData)};
testInput  = {cell2mat(test.CapWaveData), cell2mat(test.DiffWaveData)};

% =============================================
% ハイパーパラメータ抽出
% =============================================
initialLearnRate = params.InitialLearnRate;
maxEpoch        = params.MaxEpoch;
miniBatchSize   = params.MiniBatchSize;
hiddenUnitSize  = params.HiddenUnitSize;

% --- 固定パラメータ ---
denseUnitAmount = 50; % Final FC層の入力サイズなど、固定値をここで定義

% =============================================
% 学習オプション作成
% =============================================
classificationTrainOptionCreator = TrainOptionCreatorTwo(train, test);
trainOptionObj = classificationTrainOptionCreator.createNormalTrainOption(...
    initialLearnRate, maxEpoch, miniBatchSize, ...
    150, 1, 20); % frequency, repeat, tolerance
option = trainOptionObj.option;

% =============================================
% レイヤー構築
% =============================================
layerSettingCreator = LayerSettingCreatorTwo(train, test);
capInputSize = train.minimumLength; % 400
diffInputSize = test.minimumLength; % 400

% createDualWaveLayerGraph を使用
layers = layerSettingCreator.createDualWaveLayerGraph( ...
    capInputSize, diffInputSize, ...
    hiddenUnitSize, denseUnitAmount);

% =============================================
% モデル訓練
% =============================================
net = trainNetwork(trainInput, train.label, layers, option);

% =============================================
% 精度評価
% =============================================
YPred_train = classify(net, trainInput);
trainAcc = mean(YPred_train == train.label);

YPred_test  = classify(net, testInput);
testAcc = mean(YPred_test == test.label);

% =============================================
% 過学習指標
% =============================================
overfitIndex = trainAcc - testAcc;

% =============================================
% 結果をテーブル化
% =============================================
rowTimestamp = datetime('now','Format','yyyy-MM-dd HH:mm:ss');
resultTable = table(iteration, rowTimestamp, initialLearnRate, maxEpoch, ...
                    miniBatchSize, hiddenUnitSize, trainAcc, testAcc, overfitIndex);

% =============================================
% CSV保存
% =============================================
if isfile(resultPath)
    writetable(resultTable, resultPath, 'WriteMode', 'Append');
else
    writetable(resultTable, resultPath);
end

disp(['✅ 結果を保存しました: ' resultPath]);

% =============================================
% 最小化対象
% =============================================
lambda = 0.1;
val = (1 - testAcc) + lambda * overfitIndex;

end
