classdef TrainActivatorOneWave
    % TRAINACTIVATORONEWAVE 学習器を起動するクラス（単一波形データ対応）
    %   - 可変長シーケンス対応のために、ミニバッチキューと前処理関数を修正
    %   - MiniBatchFormat=["CTB", ""] と OutputCast='double' を使用

    properties (SetAccess = immutable)
        train TrainTestDataWave
        test TrainTestDataWave
        trainOption TrainOption
        netLayers               % カスタムループ用の層設定 (以前の layerSetting から修正)
        netSaveName string
        netSaveDirectory string
        
        HiddenUnitAmount double % Hidden Unit Sizeを保持するためのプロパティ

        layerSettingCreator LayerSettingCreatorOneWave
    end

    methods (Access = public)
        % ★★★ コンストラクタ: hiddenUnitSize を必須引数として追加 ★★★
        function obj = TrainActivatorOneWave(train, test, option, netLayers, hiddenUnitSize, layerSettingCreator, varAndName)
            arguments
                train TrainTestDataWave
                test TrainTestDataWave
                option TrainOption
                netLayers           % カスタムループ用の層設定
                hiddenUnitSize double % 隠れ層のユニット数
                layerSettingCreator LayerSettingCreatorOneWave 
                
                % 名前付き引数 (Optional)
                varAndName.netSaveName {string} = "oneWaveNet.mat";
                varAndName.netSaveDirectory {string} = "";
            end
        
            % プロパティへの代入
            obj.train = train;
            obj.test = test;
            obj.trainOption = option;
            obj.netLayers = netLayers;
            
            obj.netSaveName = varAndName.netSaveName;
            obj.netSaveDirectory = varAndName.netSaveDirectory;
            
            obj.HiddenUnitAmount = hiddenUnitSize; % Hidden Unit Sizeを保存

            % layerSettingCreator の代入
            obj.layerSettingCreator = layerSettingCreator;
        end
        
        % ==================================================================
        % 標準訓練関数 (trainnetworkを使用)
        % ==================================================================
        function [net, info] = trainWithStandardFunction(obj)
            
            % ===================================
            % 1. データ準備 (trainnetwork 用)
            % ===================================
            
            disp('データの準備中...');
            
            % 1-1. 入力データ (XTrain) の転置: [Tx1] -> [1xT] (Channel x Time)
            XTrain = cellfun(@transpose, obj.train.data, 'UniformOutput', false); 
            YTrain = obj.train.label; 
            
            % 1-3. 検証データ (ValidationData) の準備
            XValidation = cellfun(@transpose, obj.test.data, 'UniformOutput', false);
            YValidation = obj.test.label;
            validationData = {XValidation, YValidation};
            
            % ===================================
            % 2. ネットワーク層の定義とオプション設定
            % ===================================
            
            currentOptions = obj.trainOption.option;
            
            inputSize = size(XTrain{1}, 1); % 1 (チャンネル数)

            % HiddenUnitAmountをプロパティから参照
            hiddenUnitAmount = obj.HiddenUnitAmount; 
            
            % 訓練層の定義
            % createLSTMLayerForStandardTrain メソッドには classificationLayer が追加されている必要があります
            layers = obj.layerSettingCreator.createLSTMLayerForStandardTrain(inputSize, hiddenUnitAmount); 
            
            % trainingOptions の設定
            options = trainingOptions('adam', ...
                'MaxEpochs', currentOptions.MaxEpochs, ...
                'MiniBatchSize', currentOptions.MiniBatchSize, ...
                'InitialLearnRate', currentOptions.InitialLearnRate, ...
                'Shuffle', 'every-epoch', ...
                'ValidationData', validationData, ...
                'ValidationFrequency', currentOptions.ValidationFrequency, ...
                'ValidationPatience', currentOptions.ValidationPatience, ...
                'Plots', 'training-progress', ...
                'ExecutionEnvironment', 'gpu');
            
            % ===================================
            % 3. 訓練の実行
            % ===================================
            
            disp('訓練を開始します...');
            [net, info] = trainNetwork(XTrain, YTrain, layers, options);
            disp('訓練が完了しました。');

           % ==================================================
            % ★ Train / Validation / Test 精度の算出と表示
            % ==================================================
            
            miniBatchSize = currentOptions.MiniBatchSize;
            
            % -------- Train Accuracy --------
            YPredTrain = classify(net, XTrain, ...
                'MiniBatchSize', miniBatchSize, ...
                'ExecutionEnvironment', 'gpu');
            
            YTrueTrain = categorical(YTrain);
            trainAccuracy = mean(YPredTrain == YTrueTrain) * 100;
            
            % -------- Test Accuracy --------
            YPredTest = classify(net, XValidation, ...
                'MiniBatchSize', miniBatchSize, ...
                'ExecutionEnvironment', 'gpu');
            
            YTrueTest = categorical(YValidation);
            testAccuracy = mean(YPredTest == YTrueTest) * 100;
            
            % -------- Validation Accuracy（最後の値）--------
            if isfield(info, "ValidationAccuracy") && ~isempty(info.ValidationAccuracy)
                validationAccuracy = info.ValidationAccuracy(end);
            else
                validationAccuracy = NaN;
            end
            
            % -------- 表示 --------
            disp("========================================");
            disp("📊 Final Accuracy Summary (Standard Train)");
            disp("========================================");
            disp("Training    Accuracy : " + num2str(trainAccuracy, "%.2f") + " %");
            disp("Validation  Accuracy : " + num2str(validationAccuracy, "%.2f") + " %");
            disp("Test        Accuracy : " + num2str(testAccuracy, "%.2f") + " %");
            disp("========================================");


            
            % 訓練後のネットを保存
            if ~isempty(obj.netSaveDirectory)
                saveDir = obj.netSaveDirectory;
                if not(exist(saveDir,'dir')); mkdir(saveDir); end
                save(fullfile(saveDir, obj.netSaveName), 'net', 'info');
                disp(['✅ 訓練済みネットワークを保存しました: ', fullfile(saveDir, obj.netSaveName)]);
            end
        end

        % ==================================================================
        % 訓練起動メソッド (カスタムループ維持)
        % ==================================================================
        function result = customLossFuncActivate(obj, labelOutPutLayerName, lossFunc, dirName)
            arguments
                obj TrainActivatorOneWave
                labelOutPutLayerName string
                lossFunc  
                dirName string
            end
             
            net = dlnetwork(obj.netLayers); % カスタム層設定を使用
            nets = cell(1,obj.trainOption.trainRepeatAmount);

            % オプション設定の抽出
            maxEpochs = obj.trainOption.option.MaxEpochs;
            gradientThreshold = obj.trainOption.option.GradientThreshold;
            frequency = obj.trainOption.option.ValidationFrequency;
            stopNumber = obj.trainOption.option.ValidationPatience;
            miniBatchSize = obj.trainOption.option.MiniBatchSize;
            repeatAmount = obj.trainOption.trainRepeatAmount;
            classes = categories(categorical(obj.train.labelStrings));
            
            % 訓練ループ ===================================================
            for i = 1:repeatAmount
                trailingAvg = []; trailingAvgSq = [];
                numIterationsPerEpoch = ceil(numel(obj.train.data) / miniBatchSize);
                maxIterations = maxEpochs * numIterationsPerEpoch;
                
                % モニター設定
                monitor = trainingProgressMonitor;
                monitor.Info = ["Epoch","Iteration"];
                monitor.Metrics = ["TrainingLoss","ValidationLoss","TrainingAccuracy","ValidationAccuracy"];
                monitor.XLabel = "Iteration";
                groupSubPlot(monitor,"Accuracy",["TrainingAccuracy","ValidationAccuracy"]);
                groupSubPlot(monitor,"Loss",["TrainingLoss","ValidationLoss"]);
                epoch = 0; iteration = 0;
                minimumValidationLoss = Inf;
                shouldStopCount = 0; isStopped = false;

                % ミニバッチキューの呼び出し
                mbq = obj.createMiniBatchQueueOf_verOneWave(obj.train);
                reset(mbq); 
                
                % 検証ミニバッチキューの準備
                validationData = obj.trainOption.option.ValidationData{1};
                validationLabel = obj.trainOption.option.ValidationData{2};
                validationMbq = obj.createValidationMiniBatchOf_verOneWave(validationData, validationLabel);
                
                shuffle(validationMbq);
                while epoch < maxEpochs && ~monitor.Stop && ~isStopped
                    epoch = epoch + 1;
                    shuffle(mbq)
                    while hasdata(mbq) && ~monitor.Stop
                        iteration = iteration + 1;
                        [trainData,label] = next(mbq);
                        
                        % 順伝播、勾配計算、損失計算
                        [loss,gradients,state] = dlfeval(lossFunc(labelOutPutLayerName),net,trainData,label);
                        net.State = state;
                        
                        % パラメータ更新
                        gradients = dlupdate(@(g) thresholdL2Norm(g, gradientThreshold),gradients);
                        [net,trailingAvg,trailingAvgSq] = adamupdate(net,gradients, trailingAvg,trailingAvgSq,iteration);
                        
                        % 検証 (Validation)
                        if(mod(iteration,frequency)==0|| iteration==1)
                            if(~hasdata(validationMbq)); shuffle(validationMbq); end
                            [validationTrainData, validationLabel] = next(validationMbq);
                            
                            % 訓練精度
                            predictedLabel = predict(net,trainData,Outputs=[labelOutPutLayerName]);
                            accuracy = 100*sum(onehotdecode(predictedLabel,classes,1)==onehotdecode(label,classes,1))/miniBatchSize;
                            
                            % 検証精度と損失
                            validationPredictedLabel = predict(net,validationTrainData,Outputs=[labelOutPutLayerName]);
                            decodeValidationPredictedLabel = onehotdecode(validationPredictedLabel , classes,1,"categorical");
                            decodeValidationLabel = onehotdecode(validationLabel,classes,1,"categorical");
                            validationAccuracy = 100*sum(decodeValidationPredictedLabel==decodeValidationLabel)/miniBatchSize;
                            [validationLoss,~,~] = dlfeval(lossFunc(labelOutPutLayerName),net,validationTrainData, validationLabel);
                            
                            % Early Stopping
                            if(validationLoss>minimumValidationLoss); shouldStopCount = shouldStopCount+1;
                            else; shouldStopCount = 0; minimumValidationLoss = validationLoss; end
                            if(shouldStopCount > stopNumber); isStopped = true; break; end
                        end
                        % プロセスモニターの更新
                        updateInfo(monitor, Epoch=string(epoch) + " of " + string(maxEpochs), Iteration=string(iteration) + " of " + string(maxIterations));
                        recordMetrics(monitor,iteration, TrainingAccuracy=accuracy, ValidationAccuracy=validationAccuracy);
                        recordMetrics(monitor,iteration, TrainingLoss=loss, ValidationLoss=validationLoss);
                        monitor.Progress = 100*iteration/maxIterations;
                    end
                end
                
                % 訓練後の処理
                nets{i} = net;
            end
            
            % テストロジック ==============================================
            
            mbqTest = obj.createMiniBatchQueueOf_verOneWave(obj.test); 
            
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
                    
                    % 予測結果をOne-Hot dlarrayからcategorical文字列にデコード
                    predictedLabel = extractdata(gather(predictedLabel)); 
                    predictedLabels((loopNum-1)*miniBatchSize+1:loopNum*miniBatchSize) = ...
                        onehotdecode(predictedLabel,classes,1,"categorical");
                        
                    % 正解ラベルをOne-Hot dlarrayからcategorical文字列にデコード
                    labelBatch = extractdata(gather(label));
                    labels((loopNum-1)*miniBatchSize+1:loopNum*miniBatchSize) = ...
                        onehotdecode(labelBatch,classes,1,"categorical");
                        
                    loopNum = loopNum+1;
                end
                
                totalPredictedLabel((idx-1)*testDataAmount+1:idx*testDataAmount,1) = predictedLabels;
                totalLabel((idx-1)*testDataAmount+1:idx*testDataAmount,1) = labels;
            end

            % 結果の保存ロジック==========================================
            
            accuracy = sum(totalPredictedLabel==totalLabel) / (testDataAmount * repeatAmount); 
            disp(['Final Test Accuracy: ', num2str(accuracy)]);
            result = []; % TrainResult オブジェクトに置き換えてください
        end
    end

    methods (Access = private)
        % ==================================================================
        % プライベートメソッド: 訓練/テスト用ミニバッチキュー作成 (単一波形用)
        % ==================================================================
        function [mbq] = createMiniBatchQueueOf_verOneWave(obj, trainTestData)
            miniBatchSize = obj.trainOption.option.MiniBatchSize;
            
            vanillaTrainDataStore = arrayDatastore(trainTestData.data,"ReadSize", miniBatchSize, "OutputType", "same");
            LabelStore = arrayDatastore(trainTestData.label,"ReadSize", miniBatchSize);
            trainDataStore = combine(vanillaTrainDataStore,LabelStore);
            
            mbq = minibatchqueue(trainDataStore,...
                OutputCast='double',... % DL訓練のためにdouble型にキャスト
                PartialMiniBatch='discard',...
                MiniBatchSize=miniBatchSize,...
                MiniBatchFcn=@preprocessOneWaveData,... % 外部関数呼び出し
                MiniBatchFormat=["CTB", "" ]); 
        end
        
        % ==================================================================
        % プライベートメソッド: 検証用ミニバッチキュー作成 (単一波形用)
        % ==================================================================
        function [validationMbq] = createValidationMiniBatchOf_verOneWave(obj, data,label)
            miniBatchSize = obj.trainOption.option.MiniBatchSize;
            
            vanillaTrainDataStore = arrayDatastore(data,"ReadSize",miniBatchSize, "OutputType","same");
            LabelStore = arrayDatastore(label,"ReadSize",miniBatchSize);
            validationDataStore = combine(vanillaTrainDataStore,LabelStore);
            
            validationMbq = minibatchqueue(validationDataStore,...
                OutputCast='double',... % DL訓練のためにdouble型にキャスト
                PartialMiniBatch='discard',...
                MiniBatchSize=miniBatchSize, ...
                MiniBatchFcn=@preprocessOneWaveData, ... % 外部関数呼び出し
                MiniBatchFormat=["CTB", "" ]); 
        end
        
    end
end