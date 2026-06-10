function val = optimizeModelOneWave(params)

% ===================================================================
% 1. 初期設定とデータの読み込み
% ===================================================================

% 以前のステップで作成・保存した TrainTestDataWave オブジェクトをロード
% このロード処理により、毎回データ前処理を行う手間を省いています。
try
    load('train.mat', 'train'); 
    load('test.mat', 'test');
catch
    error('train.mat または test.mat が見つからないか、TrainTestDataWave インスタンスを含んでいません。データ準備ステップを確認してください。');
end

% === ハイパーパラメータの抽出 (bayesoptから渡される) ===
initialLearnRate = params.InitialLearnRate;
maxEpoch = params.MaxEpoch;
miniBatchSize = params.MiniBatchSize;
hiddenUnitSize = params.HiddenUnitSize;

% ===================================================================
% 2. 訓練設定オブジェクトの作成
% ===================================================================

% TrainOptionCreatorWave を使用して trainingOptions オブジェクトを作成
classificationTrainOptionCreator = TrainOptionCreatorWave(train, test); 

% frequency, repeat, tolerance はベイズ最適化の試行中、固定値を使用
frequency = 25; 
trainRepeatAmount = 1;
toleranceTimesForNotImproving = 50;

trainOptionObj = classificationTrainOptionCreator.createNormalTrainOptionWave(...
    initialLearnRate, maxEpoch, miniBatchSize, ...
    frequency, trainRepeatAmount, toleranceTimesForNotImproving);

% trainingOptions 構造体を取得
options = trainOptionObj.option;
options.ExecutionEnvironment = 'gpu'; % GPUがあれば高速化のため使用

% ===================================================================
% 3. ネットワーク層の構築
% ===================================================================

layerSettingCreator = LayerSettingCreatorOneWave(train, test);
inputSize = 1; % 単一波形データの場合、チャンネル数 (特徴量) は 1
% LSTM層と、それに続く全結合層、分類層を含む層配列を生成
layers = layerSettingCreator.createLSTMLayerForStandardTrain(inputSize, hiddenUnitSize);

% ===================================================================
% 4. trainnetwork 用データ準備 (転置)
% ===================================================================

% trainnetwork は [Channel x Time x Batch] 形式を期待するため、波形データ [Time x 1] を [1 x Time] に転置
XTrain = cellfun(@transpose, train.data, 'UniformOutput', false); 
YTrain = train.label; 
XTest = cellfun(@transpose, test.data, 'UniformOutput', false);
YTest = test.label;

% 検証データとしてテストデータを使用
XValidation = XTest;
YValidation = YTest;
options.ValidationData = {XValidation, YValidation};

% ===================================================================
% 5. モデル訓練の実行
% ===================================================================

disp('--------------------------------------------------');
disp(['Trial: LR=', num2str(initialLearnRate), ', Epoch=', num2str(maxEpoch), ', Hidden=', num2str(hiddenUnitSize)]);
[net, info] = trainNetwork(XTrain, YTrain, layers, options);

% ===================================================================
% 6. 評価と目的関数の計算
% ===================================================================

% 訓練精度の計算
YPred_train = classify(net, XTrain);
trainAcc = mean(YPred_train == YTrain);

% テスト精度の計算
YPred_test = classify(net, XTest);
testAcc = mean(YPred_test == YTest);

% 過学習指標: 訓練精度とテスト精度の差 (小さいほど汎化性能が高い)
overfitIndex = trainAcc - testAcc;

% ★★★ 目的関数 (Objective Function) の定義 ★★★
% ベイズ最適化は 'val' の最小化を目指します。
% val = (1 - テスト精度) + W * (過学習指標)
% W (重み) = 0.1 を使用し、過学習にペナルティを課す。

W = 0; 
val = (1 - testAcc) + W * overfitIndex; 

% ===================================================================
% (追加) 混同行列の表示と保存
% ===================================================================

% 混同行列のチャートを作成
% ベイズ最適化中はウィンドウが大量に出ないよう 'Visible', 'off' で作成し、保存後に閉じます
fig = figure('Visible', 'off'); 
cm = confusionchart(YTest, YPred_test);

% タイトルに試行条件を含める (後で識別しやすくするため)
cm.Title = ['Test Confusion Matrix (LR=' num2str(initialLearnRate) ...
            ', Hidden=' num2str(hiddenUnitSize) ')'];

% オプション: 行/列の正規化（再現率や適合率を表示したい場合）
cm.RowSummary = 'row-normalized';     % 正解クラスごとの正解率 (Recall)
cm.ColumnSummary = 'column-normalized'; % 予測クラスごとの正解率 (Precision)

% --- 画像の保存 ---
% 保存先ディレクトリ (Section 7と同じ場所を使用するため、saveDirの定義をここに移動するか、再定義が必要です)
saveDir = fullfile(pwd, 'BayesOptResults');
if ~exist(saveDir, 'dir'); mkdir(saveDir); end

% タイムスタンプとファイル名
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
imgName = sprintf('ConfMat_LR%.4f_H%d_%s.png', initialLearnRate, hiddenUnitSize, timestamp);
imgPath = fullfile(saveDir, imgName);

% 画像を保存 (exportgraphics は R2020a以降推奨。古い場合は saveas(fig, imgPath) を使用)
try
    exportgraphics(fig, imgPath); 
catch
    saveas(fig, imgPath);
end

% メモリ節約のため図を閉じる
close(fig);

% ===================================================================
% 7. 結果のロギングと保存
% ===================================================================

resultTable = table(initialLearnRate, maxEpoch, miniBatchSize, hiddenUnitSize, ...
                    trainAcc, testAcc, overfitIndex, val);

timestamp = datestr(now, 'yyyymmdd_HHMMSS');
% ★★★ 適切な保存先ディレクトリに変更してください ★★★
% 現在のフォルダ (pwd) の下の 'BayesOptResults' フォルダを使用
saveDir = fullfile(pwd, 'BayesOptResults');
if ~exist(saveDir, 'dir'); mkdir(saveDir); end

resultPath = fullfile(saveDir, sprintf('bayesopt_oneWave_results_%s.csv', timestamp));
writetable(resultTable, resultPath);
disp(['✅ 結果を保存しました: ' resultPath]);
disp(['Objective Value (最小化対象): ', num2str(val)]);
disp('--------------------------------------------------');

end