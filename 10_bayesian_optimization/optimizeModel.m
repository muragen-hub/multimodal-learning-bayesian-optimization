function val = optimizeModel(params)
    % === データの読み込み ===
    load train.mat
    load test.mat

    % === ハイパーパラメータの抽出 ===
    initialLearnRate = params.InitialLearnRate;
    maxEpoch = params.MaxEpoch;
    miniBatchSize = params.MiniBatchSize;
    hiddenUnitSize = params.HiddenUnitSize;

    % === オプション作成 ===
    classificationTrainOptionCreator = TrainOptionCreator(train, test);
    trainOptionObj = classificationTrainOptionCreator.createNormalTrainOption(...
        initialLearnRate, maxEpoch, miniBatchSize, ...
        150, 1, 20);  % frequency, repeat, tolerance固定


    % TrainOption オブジェクト内部の trainingOptions を取り出す
    option = trainOptionObj.option;


    % === レイヤー構築 ===
    layerSettingCreator = LayerSettingCreator(train, test);
    inputsize = 2; % 圧力 + 静電容量の2系列
    layers = layerSettingCreator.createSingleLSTMLayer(inputsize, hiddenUnitSize);


    % === モデル訓練 ===
    net = trainNetwork(train.data, train.label, layers, option);

    % === 評価 ===
    YPred_train = classify(net, train.data);
    trainAcc = mean(YPred_train == train.label);

    YPred_test = classify(net, test.data);
    testAcc = mean(YPred_test == test.label);

    % === 過学習の数値化 ===
    overfitIndex = trainAcc - testAcc;

    % === 結果をCSVに保存 ===
    resultTable = table(initialLearnRate, maxEpoch, miniBatchSize, hiddenUnitSize, ...
                        trainAcc, testAcc, overfitIndex);
    
    % === 保存先ディレクトリ ===
    saveDir = '/home/twophaseflow/deepLearningForMultiMeter/deepLearningForMultiMeter/File_MURATA';

    % === タイムスタンプ付きファイル名を生成 ===
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');  % 例: 20251024_161230
    resultPath = fullfile(saveDir, sprintf('bayesopt_results_%s.csv', timestamp));

    % === CSVに保存 ===
    writetable(resultTable, resultPath);
    disp(['✅ 結果を保存しました: ' resultPath]);

    % === 最小化対象（負の精度） ===
    val = 1 - testAcc;
end

