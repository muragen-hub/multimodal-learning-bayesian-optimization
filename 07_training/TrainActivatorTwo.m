classdef TrainActivatorTwo
    % TrainActivatorTwo 学習器を起動するクラス
    %   カスタム損失関数版・マルチモーダル版・全て含む
    properties (SetAccess = immutable)
        train TrainTestDataTwo
        test TrainTestDataTwo
        trainOption TrainOption
        layerSetting
        netSaveName string
        netSaveDirectory string
    end

    methods
        function obj = TrainActivatorTwo(trainDataInstance, testDataInstance, option, layer, varargin)
            % --- コンストラクタ ---
            p = inputParser;
            addRequired(p, 'trainDataInstance');
            addRequired(p, 'testDataInstance');
            addRequired(p, 'option');
            addRequired(p, 'layer');
            addParameter(p, 'netSaveName', "net.mat");
            addParameter(p, 'netSaveDirectory', "results/");
            parse(p, trainDataInstance, testDataInstance, option, layer, varargin{:});

            obj.train = p.Results.trainDataInstance;
            obj.test = p.Results.testDataInstance;
            obj.trainOption = p.Results.option;
            obj.layerSetting = p.Results.layer;
            obj.netSaveName = p.Results.netSaveName;
            obj.netSaveDirectory = p.Results.netSaveDirectory;
        end
        % ============================================================
        % ① カスタム損失関数での通常学習
        % ============================================================
        function result = customLossFuncActivate(obj, labelOutPutLayerName, lossFunc, dirName)
            arguments
                obj TrainActivatorTwo
                labelOutPutLayerName string
                lossFunc 
                dirName string
            end

            net = dlnetwork(obj.layerSetting);
            nets = cell(1, obj.trainOption.trainRepeatAmount);

            % === オプション読み込み ===
            maxEpochs = obj.trainOption.option.MaxEpochs;
            gradientThreshold = obj.trainOption.option.GradientThreshold;
            frequency = obj.trainOption.option.ValidationFrequency;
            stopNumber = obj.trainOption.option.ValidationPatience;
            miniBatchSize = obj.trainOption.option.MiniBatchSize;
            repeatAmount = obj.trainOption.trainRepeatAmount;
            classes = categories(categorical(obj.train.labelStrings));

            finalValidationAcc = 0; 

            % === 学習ループ ===
            for i = 1:repeatAmount
                trailingAvg = [];
                trailingAvgSq = [];
                numIterationsPerEpoch = ceil(numel(obj.train.data) / miniBatchSize);
                maxIterations = maxEpochs * numIterationsPerEpoch;
                monitor = trainingProgressMonitor;
                monitor.Info = ["Epoch","Iteration"];
                monitor.Metrics = ["TrainingLoss","ValidationLoss","TrainingAccuracy","ValidationAccuracy"];
                monitor.XLabel = "Iteration";
                groupSubPlot(monitor,"Accuracy",["TrainingAccuracy","ValidationAccuracy"]);
                groupSubPlot(monitor,"Loss",["TrainingLoss","ValidationLoss"]);
                
                epoch = 0;
                iteration = 0;
                minimumValidationLoss = Inf;
                shouldStopCount = 0;
                isStopped = false;

                mbq = obj.createMiniBatchQueueOf(obj.train);
                validationData = obj.trainOption.option.ValidationData{1};
                validationLabel = obj.trainOption.option.ValidationData{2};
                validationMbq = obj.createValidationMiniBatchOf(validationData, validationLabel);
                shuffle(validationMbq);

                while epoch < maxEpochs && ~monitor.Stop && ~isStopped
                    epoch = epoch + 1;
                    shuffle(mbq)

                    while hasdata(mbq) && ~monitor.Stop
                        iteration = iteration + 1;
                        [trainData,label] = next(mbq);
                        [loss,gradients,state] = dlfeval(lossFunc(labelOutPutLayerName),net,trainData,label);
                        net.State = state;

                        gradients = dlupdate(@(g) thresholdL2Norm(g, gradientThreshold), gradients);
                        [net,trailingAvg,trailingAvgSq] = adamupdate(net,gradients,trailingAvg,trailingAvgSq,iteration);

                        if mod(iteration,frequency)==0 || iteration==1
                            if ~hasdata(validationMbq)
                                shuffle(validationMbq);
                            end
                            [validationTrainData, validationLabel] = next(validationMbq);

                            predictedLabel = predict(net,trainData,Outputs=[labelOutPutLayerName]);
                            accuracy = 100 * sum(onehotdecode(predictedLabel,classes,1)==onehotdecode(label,classes,1)) / miniBatchSize;

                            validationPredictedLabel = predict(net,validationTrainData,Outputs=[labelOutPutLayerName]);
                            decodeValidationPredictedLabel = onehotdecode(validationPredictedLabel , classes,1,"categorical");
                            decodeValidationLabel = onehotdecode(validationLabel,classes,1,"categorical");
                            validationAccuracy = 100 * sum(decodeValidationPredictedLabel==decodeValidationLabel) / miniBatchSize;

                            finalValidationAcc = validationAccuracy / 100;

                            [validationLoss,~,~] = dlfeval(lossFunc(labelOutPutLayerName),net,validationTrainData, validationLabel);
                            if validationLoss > minimumValidationLoss
                                shouldStopCount = shouldStopCount + 1;
                            else
                                shouldStopCount = 0;
                                minimumValidationLoss = validationLoss;
                            end

                            if shouldStopCount > stopNumber
                                isStopped = true;
                                break;
                            end
                        end

                        updateInfo(monitor, ...
                            Epoch=string(epoch) + " of " + string(maxEpochs), ...
                            Iteration=string(iteration) + " of " + string(maxIterations));

                        recordMetrics(monitor,iteration, ...
                            TrainingAccuracy=accuracy, ...
                            ValidationAccuracy=validationAccuracy, ...
                            TrainingLoss=loss, ...
                            ValidationLoss=validationLoss);

                        monitor.Progress = 100 * iteration / maxIterations;
                    end
                end

                nets{i} = net;
            end

            % === テスト評価 ===
            miniBatchSize = obj.trainOption.option.MiniBatchSize;
            mbqTest = obj.createMiniBatchQueueOf(obj.test);
            roughTestDataAmount = length(obj.test.data);
            testDataAmount = fix(roughTestDataAmount/miniBatchSize)*miniBatchSize;

            predictedLabels = strings(testDataAmount,1);
            labels = strings(testDataAmount,1);
            totalPredictedLabel = strings(testDataAmount*repeatAmount,1);
            totalLabel = strings(testDataAmount*repeatAmount,1);

            for idx = 1:repeatAmount
                reset(mbqTest);
                loopNum = 1;
                while hasdata(mbqTest)
                    [testData,label] = next(mbqTest);
                    predictedLabel = predict(nets{idx},testData,Outputs=[labelOutPutLayerName]);
                    predictedLabel = extractdata(gather(predictedLabel));
                    predictedLabels((loopNum-1)*miniBatchSize+1:loopNum*miniBatchSize) = onehotdecode(predictedLabel,classes,1,"categorical");
                    labelBatch = extractdata(gather(label));
                    labels((loopNum-1)*miniBatchSize+1:loopNum*miniBatchSize) = onehotdecode(labelBatch,classes,1,"categorical");
                    loopNum = loopNum + 1;
                end
                totalPredictedLabel((idx-1)*testDataAmount+1:idx*testDataAmount,1) = predictedLabels;
                totalLabel((idx-1)*testDataAmount+1:idx*testDataAmount,1) = labels;
            end

            testAcc = sum(totalPredictedLabel==totalLabel) / (testDataAmount * repeatAmount);
            trainAcc = finalValidationAcc;

            result = TrainResult(nets,obj.train.conditionStrings,obj.train.labelStrings,totalPredictedLabel ,totalLabel, trainAcc, testAcc);

            % === 結果保存 ===
            dirName = append(deepNetSavePath.path,obj.netSaveDirectory);
            if not(exist(dirName,'dir'))
                mkdir(dirName)
            end
            writelines(append("Accuracy: ",string(testAcc)), append(dirName,"accuracy.txt"), WriteMode="append");
            save(append(dirName,obj.netSaveName),'result');

            % === 過学習度を計算して表示 ===
            overfitAmount = trainAcc - testAcc;
            disp("==== 学習結果 ====");
            disp("Train Accuracy: " + string(trainAcc));
            disp("Test  Accuracy: " + string(testAcc));
            disp("過学習度 (Train - Test): " + string(overfitAmount));
        end

        % ============================================================
        % ② 通常学習 (trainNetwork)
        % ============================================================
        function result = activate(obj, dirName)
            arguments
                obj TrainActivatorTwo
                dirName string
            end
            nets = cell(1,obj.trainOption.trainRepeatAmount);
            minimumLength = obj.test.minimumLength;
            repeatAmount = obj.trainOption.trainRepeatAmount;
            conditionLength = length(obj.train.conditionStrings);
            allPrediction = strings(minimumLength*repeatAmount*conditionLength,1);
            allTest = strings(minimumLength*repeatAmount*conditionLength,1);

            finalTrainAcc = 0;
            finalTestAcc = 0;

            for i = 1:repeatAmount
                net = trainNetwork(obj.train.data,obj.train.label,obj.layerSetting, obj.trainOption.option);
                prediction = classify(net,obj.test.data);
                testAcc = sum(prediction==obj.test.label)./numel(obj.test.label);
                predictionTrain = classify(net,obj.train.data);
                trainAcc = sum(predictionTrain==obj.train.label)./numel(obj.train.label);

                allPrediction(1+(i-1)*minimumLength*conditionLength:i*minimumLength*conditionLength) = prediction;
                allTest(1+(i-1)*minimumLength*conditionLength:i*minimumLength*conditionLength) = obj.test.label;

                disp(testAcc);
                nets{i} = net;

                if i == repeatAmount
                    finalTrainAcc = trainAcc;
                    finalTestAcc = testAcc;
                end
            end

            allPrediction = categorical(allPrediction);
            allTest = categorical(allTest);

            result = TrainResult(nets,obj.train.conditionStrings,obj.train.labelStrings,allPrediction,allTest,finalTrainAcc,finalTestAcc);

            dirName = append(deepNetSavePath.path,obj.netSaveDirectory);
            if not(exist(dirName,'dir'))
                mkdir(dirName)
            end
            save(append(dirName,obj.netSaveName),'result');

            % === 過学習度を計算して表示 ===
            overfitAmount = finalTrainAcc - finalTestAcc;
            disp("==== 学習結果 ====");
            disp("Train Accuracy: " + string(finalTrainAcc));
            disp("Test  Accuracy: " + string(finalTestAcc));
            disp("過学習度 (Train - Test): " + string(overfitAmount));
        end

        % ============================================================
        % ③ マルチモーダル学習 (trainNetwork) - 波形二つ入力対応
        % ============================================================
        function result = activateDualWave(obj, dirName) % ★ メソッド名を変更 ★
            arguments
                obj TrainActivatorTwo
                dirName string
            end
            
            nets = cell(1, obj.trainOption.trainRepeatAmount);
            repeatAmount = obj.trainOption.trainRepeatAmount;
            
            % --- 訓練・テストデータをマルチインプット形式に整形 ---
            
            % 訓練データ: CapWaveDataとDiffWaveDataは、既にシーケンスのCell配列形式
            % trainNetworkは、マルチインプットとして Cell配列 {CellArray_CapWave, CellArray_DiffWave}
            % を受け付ける。Cell配列の中身はシーケンスデータ。
            
            % ★ 🚨 修正箇所: cell2mat を削除 ★
            trainInputData = {obj.train.CapWaveData, obj.train.DiffWaveData};
            trainLabel = obj.train.label;
            
            % テストデータ
            % ★ 🚨 修正箇所: cell2mat を削除 ★
            testInputData = {obj.test.CapWaveData, obj.test.DiffWaveData};
            testLabel = obj.test.label;
            
            
            % メタデータ
            testDataAmount = numel(testLabel); % テストデータの総セグメント数
            
            allPrediction = strings(testDataAmount * repeatAmount, 1);
            allTest = strings(testDataAmount * repeatAmount, 1);
            finalTrainAcc = 0;
            finalTestAcc = 0;
            
            for i = 1:repeatAmount
                % trainNetwork に Cell配列 {X_capa, X_dp} とラベルを渡す
                % 入力データが {CellArray, CellArray} の形式なので、マルチインプットとして認識され、エラーが解消する
                
                net = trainNetwork(trainInputData, trainLabel, obj.layerSetting, obj.trainOption.option);
                
                % テストデータで分類 (Cell配列を入力として渡す)
                prediction = classify(net, testInputData);
                testAcc = sum(prediction == testLabel) ./ numel(testLabel);
                
                % 訓練データで精度確認
                predictionTrain = classify(net, trainInputData);
                trainAcc = sum(predictionTrain == trainLabel) ./ numel(trainLabel);
                
                % 結果を格納
                allPrediction(1 + (i-1)*testDataAmount : i*testDataAmount) = prediction;
                allTest(1 + (i-1)*testDataAmount : i*testDataAmount) = testLabel;
                
                disp(['Repeat ' num2str(i) ' Test Acc: ' num2str(testAcc)]);
                nets{i} = net;
                
                if i == repeatAmount
                    finalTrainAcc = trainAcc;
                    finalTestAcc = testAcc;
                end
            end
            
            allPrediction = categorical(allPrediction);
            allTest = categorical(allTest);
            
            % TrainResult の作成と保存
            result = TrainResult(nets, obj.train.conditionStrings, obj.train.labelStrings, allPrediction, allTest, finalTrainAcc, finalTestAcc);
            
            dirName = append(deepNetSavePath.path, obj.netSaveDirectory);
            if not(exist(dirName, 'dir'))
                mkdir(dirName)
            end
            save(append(dirName, obj.netSaveName), 'result');
            
            % === 過学習度を計算して表示 ===
            overfitAmount = finalTrainAcc - finalTestAcc;
            disp("==== 学習結果 ====");
            disp("Train Accuracy: " + string(finalTrainAcc));
            disp("Test  Accuracy: " + string(finalTestAcc));
            disp("過学習度 (Train - Test): " + string(overfitAmount));
        end
        
        % ===============================================================
        % ★ customActivateMultimodal (メイン学習関数) ★
        % ===============================================================
        function [trainedNet, trainInfo] = customActivateMultimodal(obj)
            %% === 1. データ取得と前処理 ===
            % 静的特徴量をセルにして double に統一
            featTrainCell = num2cell(obj.train.FeatureData, 2);
            featTrainCell = cellfun(@(x) double(x), featTrainCell, 'UniformOutput', false);
            featTestCell  = num2cell(obj.test.FeatureData, 2);
            featTestCell  = cellfun(@(x) double(x), featTestCell, 'UniformOutput', false);
            classes = categories(obj.train.label);
            classificationLoss = @(Y, T) crossentropy(Y, T);
            % 波形を double セルに統一
            capTrainDoubleCell  = cellfun(@double, obj.train.CapWaveData,  'UniformOutput', false);
            diffTrainDoubleCell = cellfun(@double, obj.train.DiffWaveData, 'UniformOutput', false);
            capTestDoubleCell   = cellfun(@double, obj.test.CapWaveData,   'UniformOutput', false);
            diffTestDoubleCell  = cellfun(@double, obj.test.DiffWaveData,  'UniformOutput', false);
            % 簡易チェック：各セル内のテンソル形状がサンプル間で揃っているか（cat(4) 前に確認）
            assertUniformSizes(capTrainDoubleCell, 'capTrainDoubleCell');
            assertUniformSizes(diffTrainDoubleCell, 'diffTrainDoubleCell');
            assertUniformSizes(capTestDoubleCell, 'capTestDoubleCell');
            assertUniformSizes(diffTestDoubleCell, 'diffTestDoubleCell');
           
            %% === 2. 訓練/検証 Datastore の作成 (基本 Datastore モード) ===
            % MiniBatchDatastoreを使用せず、dsTrain/dsValをそのまま使用します。
            dsTrain = combine( ...
                arrayDatastore(capTrainDoubleCell), ...
                arrayDatastore(diffTrainDoubleCell), ...
                arrayDatastore(featTrainCell), ...
                arrayDatastore(obj.train.label) );
            dsVal = combine( ...
                arrayDatastore(capTestDoubleCell), ...
                arrayDatastore(diffTestDoubleCell), ...
                arrayDatastore(featTestCell), ...
                arrayDatastore(obj.test.label) );
            
            % MiniBatchSizeをローカル変数に格納
            miniBatchSize = obj.trainOption.option.MiniBatchSize;
            
            %% === 3. モデル構築とループ準備 ===
            net = dlnetwork(obj.layerSetting);
            numEpochs = obj.trainOption.option.MaxEpochs;
            learnRate = obj.trainOption.option.InitialLearnRate;
            trailingAvg = [];
            trailingAvgSq = [];
            iteration = 0;
            % 追跡用配列
            trLossAll = zeros(numEpochs,1); valLossAll = zeros(numEpochs,1);
            trAccAll = zeros(numEpochs,1); valAccAll = zeros(numEpochs,1);
            overfitAll = zeros(numEpochs,1);

            % trainingProgressMonitor の初期化 (全てのメトリクスを'Metrics'に統合)
            monitor = trainingProgressMonitor(...
                'Metrics', {'Loss', 'ValidationLoss', 'Accuracy', 'ValidationAccuracy', 'OverfittingDegree'},... 
                'Info', {'Epoch','Iteration','LearningRate'});
            
            %% === 4. 学習ループ (Datastore手動操作モード) ===
            for epoch = 1:numEpochs
                
                % Datastoreをリセットし、読み込みを最初から開始
                reset(dsTrain); 
                
                epochLoss = 0; numMB = 0;
                
                % Datastoreが読み込めるデータを持っている間ループ
                while hasdata(dsTrain) 
                    
                    % MiniBatchSize分のデータを読み込む
                    % 'BatchSize'を指定し、セル配列として受け取る
                    [capCell, diffCell, featCell, Tcat] = read(dsTrain, 'BatchSize', miniBatchSize); 
                    
                    % MiniBatchSizeに満たない場合はスキップ（PartialMiniBatchをdiscard相当にする）
                    if numel(capCell) < miniBatchSize
                        continue; 
                    end
                    
                    iteration = iteration + 1;

                    % --- 安全化: Tcat がセルなら縦ベクトルに展開 ---
                    if iscell(Tcat)
                        try
                            Tcat = vertcat(Tcat{:});
                        catch
                            error('Tcat appears as a cell but cannot be concatenated into categorical vector.');
                        end
                    end
                    
                    % --- 勾配計算と Adam更新 ---
                    [loss, grad] = dlfeval(@modelGradients, ...
                        net, capCell, diffCell, featCell, Tcat, classificationLoss, classes);
                    
                    % Adam update
                    [net, trailingAvg, trailingAvgSq] = adamupdate( ...
                        net, grad, trailingAvg, trailingAvgSq, iteration, learnRate);
                    
                    % 損失の追跡
                    currentLoss = double(extractdata(loss));
                    epochLoss = epochLoss + currentLoss;
                    numMB = numMB + 1;
                    
                    % モニター更新: ミニバッチの訓練損失をリアルタイム記録
                    recordMetrics(monitor, iteration, ...
                        'Loss', currentLoss, ...
                        'LearningRate', learnRate);
                    plot(monitor);
                end % while hasdata(dsTrain)
                
                % numMB 保護（ゼロ除算防止）
                if numMB > 0
                    trLossAll(epoch) = epochLoss / numMB;
                else
                    trLossAll(epoch) = NaN;
                end
                
                % --- エポック完了メトリクスの計算 ---
                % evaluateMetrics の引数に dsTrain と dsVal を渡します。
                [~, trAcc] = evaluateMetrics(net, dsTrain, classificationLoss, classes); 
                [valLoss, valAcc] = evaluateMetrics(net, dsVal, classificationLoss, classes);
                
                valLossAll(epoch) = valLoss;
                trAccAll(epoch) = trAcc;
                valAccAll(epoch) = valAcc;
                % 過学習度を計算
                overfitDegree = trAcc - valAcc;
                overfitAll(epoch) = overfitDegree;
                
                % モニター更新: エポック完了メトリクス
                recordMetrics(monitor, iteration, ...
                    'Accuracy', trAcc, ...
                    'ValidationLoss', valLoss, ...
                    'ValidationAccuracy', valAcc, ...
                    'OverfittingDegree', overfitDegree);
                updateInfo(monitor, 'Epoch', epoch);
                plot(monitor);
                
                % コンソール出力
                fprintf("Epoch %d/%d TrainLoss=%.4f TrainAcc=%.2f%% ValLoss=%.4f ValAcc=%.2f%% Overfit=%.2f%%\n", ...
                    epoch, numEpochs, trLossAll(epoch), trAcc * 100, valLossAll(epoch), valAccAll(epoch) * 100, overfitDegree * 100);
            end
            %% === 5. 結果まとめと保存 ===
            trainInfo.trainLoss = trLossAll;
            trainInfo.valLoss = valLossAll;
            trainInfo.trainAccuracy = trAccAll;
            trainInfo.valAccuracy = valAccAll;
            trainInfo.overfittingDegree = overfitAll;
            trainedNet = net;
            % 結果の保存
            if ~isfolder(obj.netSaveDirectory)
                mkdir(obj.netSaveDirectory);
            end
            savePath = fullfile(obj.netSaveDirectory, obj.netSaveName);
            save(savePath, 'trainedNet', 'trainInfo');
            fprintf('Trained network and info saved to: %s\n', savePath);
        end % customActivateMultimodal end
    end % methods
end % classdef

% -----------------------------------------------------------------
% ローカル関数 (手動バッチ化モードに対応)
% -----------------------------------------------------------------
function [loss, gradients] = modelGradients(net, capCell, diffCell, featCell, Tcat, lossFunc, classes)
    % モデルの順伝播、損失計算、勾配計算を行う (入力はセル配列)
    % --- 安全化: Tcat がセルなら縦ベクトルに展開 ---
    if iscell(Tcat)
        Tcat = vertcat(Tcat{:});
    end
    % CapWave/DiffWave のバッチ化と dlarray 変換 (SSCB形式)
    capBatch = cat(4, capCell{:});
    diffBatch = cat(4, diffCell{:});
    cap_dl = dlarray(capBatch, 'SSCB');
    diff_dl = dlarray(diffBatch, 'SSCB');
    % 静的特徴量 (featCell) のバッチ化と dlarray 変換 (CB形式)
    featVectors = cellfun(@(x) reshape(x, [], 1), featCell, 'UniformOutput', false);
    featBatch = cat(2, featVectors{:});
    feat_dl = dlarray(featBatch, 'CB');
    % ラベル (Tcat) の dlarray 化（onehot）
    T_onehot = onehotencode(Tcat, 1, 'ClassNames', classes);
    T_dl = dlarray(T_onehot, 'CB');
    % forward & loss & gradients
    Y = forward(net, cap_dl, diff_dl, feat_dl);
    loss = lossFunc(Y, T_dl);
    gradients = dlgradient(loss, net.Learnables);
end

% 評価関数 evaluateMetrics の修正版 (Datastoreを直接操作)
function [avgLoss, avgAccuracy] = evaluateMetrics(net, dsDatastore, lossFunc, classes)
    % 評価データセット全体に対する損失と精度を計算する
    
    reset(dsDatastore); % Datastoreをリセット
    lossSum = 0; numCorrect = 0; totalCount = 0; numMB = 0;
    
    % Datastoreからすべてのデータを読み込む (MiniBatchSizeの概念は評価時に不要)
    while hasdata(dsDatastore) 
        
        % read(dsDatastore) は利用可能なすべてのデータを返す
        [capCell, diffCell, featCell, Tcat] = read(dsDatastore); 
        
        % データがない場合はスキップ
        if isempty(capCell)
            continue; 
        end
        
        % 安全化: Tcat がセルなら縦ベクトルに展開
        if iscell(Tcat)
            Tcat = vertcat(Tcat{:});
        end
        
        % CapWave/DiffWave の dlarray 化
        capBatch = cat(4, capCell{:});
        diffBatch = cat(4, diffCell{:});
        cap_dl = dlarray(capBatch, 'SSCB');
        diff_dl = dlarray(diffBatch, 'SSCB');
        
        % 静的特徴量 (featCell) の dlarray 化
        featVectors = cellfun(@(x) reshape(x, [], 1), featCell, 'UniformOutput', false);
        featBatch = cat(2, featVectors{:});
        feat_dl = dlarray(featBatch, 'CB');
        
        % ラベルの dlarray 化
        T_onehot = onehotencode(Tcat, 1, 'ClassNames', classes);
        T_dl = dlarray(T_onehot, 'CB');
        
        % 予測と評価
        Y = predict(net, cap_dl, diff_dl, feat_dl);
        
        lossSum = lossSum + double(extractdata(lossFunc(Y, T_dl)));
        
        [~, YpredIdx] = max(extractdata(Y), [], 1);
        [~, TtrueIdx] = max(extractdata(T_onehot), [], 1);
        
        numCorrect = numCorrect + sum(YpredIdx == TtrueIdx);
        totalCount = totalCount + numel(Tcat);
        numMB = numMB + 1;
    end
    
    if totalCount > 0
        % 評価時の損失は、読み込んだ回数（numMB）で割ります
        avgLoss = lossSum / numMB;
        avgAccuracy = numCorrect / totalCount;
    else
        avgLoss = NaN;
        avgAccuracy = NaN;
    end
end
% -----------------------------------------------------------------
% ヘルパー関数
% -----------------------------------------------------------------
function assertUniformSizes(cellArray, name)
    % cellArray の各要素のサイズが等しいかチェック（cat(4) 前に）
    if isempty(cellArray)
        return;
    end
    firstSize = size(cellArray{1});
    for i = 2:numel(cellArray)
        if ~isequal(size(cellArray{i}), firstSize)
            error('Inconsistent sizes in %s: element 1 is %s but element %d is %s. All elements must have identical sizes for cat(4).', ...
                name, mat2str(firstSize), i, mat2str(size(cellArray{i})));
        end
    end
end