classdef TrainActivatorWave
    % TRAINACTIVATORWAVE 学習器を起動する（Waveデータ対応）
    %   TrainTestDataWave と TrainOption の型に対応し、古いメソッドを削除しました。
    
    properties (SetAccess = immutable)
        train TrainTestDataWave
        test TrainTestDataWave
        trainOption TrainOption
        layerSetting
        netSaveName string
        netSaveDirectory string
    end
    
    methods (Access = public)
        function obj = TrainActivatorWave(train,test, option, layer,varAndName)
            arguments
                train TrainTestDataWave
                test TrainTestDataWave
                option TrainOption
                layer
                varAndName.netSaveName {string} = "hogehoge.mat";
                varAndName.netSaveDirectory  {string}  ="";
            end
            obj.train = train;
            obj.test = test;
            obj.trainOption = option;
            obj.layerSetting = layer;
            obj.netSaveName = varAndName.netSaveName;
            obj.netSaveDirectory = varAndName.netSaveDirectory;
        end

        %==================================================================
        % カスタム損失関数による訓練起動 (dlnetworkを使用)
        %==================================================================
        function result = customLossFuncActivate(obj, labelOutPutLayerName,lossFunc,dirName)
            arguments
                obj TrainActivatorWave
                labelOutPutLayerName string
                lossFunc 
                dirName string
            end
            
            net = dlnetwork(obj.layerSetting);
            nets = cell(1,obj.trainOption.trainRepeatAmount);
            %オプションを拾ってくる============================
            maxEpochs = obj.trainOption.option.MaxEpochs;
            gradientThreshold = obj.trainOption.option.GradientThreshold;
            frequency = obj.trainOption.option.ValidationFrequency;
            stopNumber = obj.trainOption.option.ValidationPatience;
            miniBatchSize = obj.trainOption.option.MiniBatchSize;
            %===================================================
            %ここから訓練=======================================================================
            repeatAmount = obj.trainOption.trainRepeatAmount;
            classes = categories(categorical(obj.train.labelStrings));
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
                
                % 呼び出しを簡略化
                mbq = obj.createMiniBatchQueueOf_verMultimodal(obj.train);
                
                validationData = obj.trainOption.option.ValidationData{1};
                validationLabel = obj.trainOption.option.ValidationData{2};
                
                % 呼び出しを簡略化
                validationMbq = obj.createValidationMiniBatchOf_verMultimodal(validationData, validationLabel);
                
                shuffle(validationMbq);
                while epoch < maxEpochs && ~monitor.Stop && ~isStopped
                    epoch = epoch + 1;
                    % シャッフル
                    shuffle(mbq)
                    %ミニバッチをまわし切って1-epoch
                    while hasdata(mbq) && ~monitor.Stop
                        iteration = iteration + 1;
                        [trainData,label] = next(mbq);
                        [loss,gradients,state] = dlfeval(lossFunc(labelOutPutLayerName),net,trainData,label);
                        net.State = state;
                        gradients = dlupdate(@(g) thresholdL2Norm(g, gradientThreshold),gradients);%勾配クリップ.
                        % adamを使ってネットワーク更新
                        [net,trailingAvg,trailingAvgSq] = adamupdate(net,gradients, trailingAvg,trailingAvgSq,iteration);
                        % 検証
                        if(mod(iteration,frequency)==0|| iteration==1)
                            if(~hasdata(validationMbq))
                                shuffle(validationMbq);
                            end
                            [validationTrainData, validationLabel] = next(validationMbq);
                            %精度確認
                            predictedLabel =  predict(net,trainData,Outputs=[labelOutPutLayerName]);
                            accuracy = 100*sum(onehotdecode(predictedLabel,classes,1)==onehotdecode(label,classes,1))/miniBatchSize;
                            validationPredictedLabel =  predict(net,validationTrainData,Outputs=[labelOutPutLayerName]);
                            decodeValidationPredictedLabel = onehotdecode(validationPredictedLabel , classes,1,"categorical");
                            decodeValidationLabel = onehotdecode(validationLabel,classes,1,"categorical");
                            validationAccuracy = 100*sum(decodeValidationPredictedLabel==decodeValidationLabel)/miniBatchSize;
                            [validationLoss,~,~] = dlfeval(lossFunc(labelOutPutLayerName),net,validationTrainData, validationLabel);
                            if(validationLoss>minimumValidationLoss)
                                shouldStopCount = shouldStopCount+1 ;
                            else
                                shouldStopCount = 0;
                                minimumValidationLoss = validationLoss;
                            end
                            if(shouldStopCount > stopNumber)
                                isStopped = true;
                                break;
                            end
                        end
                        % プロセスモニターの更新.
                        updateInfo(monitor, ...
                            Epoch=string(epoch) + " of " + string(maxEpochs), ...
                            Iteration=string(iteration) + " of " + string(maxIterations));
                        
                        recordMetrics(monitor,iteration, ...
                            TrainingAccuracy=accuracy, ...
                            ValidationAccuracy=validationAccuracy);
                        recordMetrics(monitor,iteration, ...
                            TrainingLoss=loss, ...
                            ValidationLoss=validationLoss);
                        monitor.Progress = 100*iteration/maxIterations;
                    end
                end
                obj.saveCustomDeepMonitor(dirName,i);
                nets{i} = net;
            end
            %====================================================================================
            %ここからテスト======================================================================
            % 呼び出しを簡略化
            mbqTest = obj.createMiniBatchQueueOf_verMultimodal(obj.test);
            
            %minibatchに中途半端なものは捨てろと命令しているため, testDataAmountは正確には総出力の量と不一致.
            roughTestDataAmount = length(obj.test.data);
            testDataAmount = fix(roughTestDataAmount/miniBatchSize)*miniBatchSize;
            
            predictedLabels =strings(testDataAmount,1);
            labels = strings(testDataAmount,1);
            
            totalPredictedLabel = strings(testDataAmount*repeatAmount,1);
            totalLabel = strings(testDataAmount*repeatAmount,1);
           
            for idx = 1:repeatAmount
                reset(mbqTest);
                loopNum = 1;
                while hasdata(mbqTest)
                    % ミニバッチからデータ引き出し
                    [testData,label] = next(mbqTest);
                    predictedLabel = predict(nets{idx},testData,Outputs=[labelOutPutLayerName]);
                    predictedLabel = extractdata(gather(predictedLabel)); 
                    predictedLabels((loopNum-1)*miniBatchSize+1:loopNum*miniBatchSize) = onehotdecode(predictedLabel,classes,1,"categorical");
                    labelBatch = extractdata(gather(label));
                    labels((loopNum-1)*miniBatchSize+1:loopNum*miniBatchSize) = onehotdecode(labelBatch,classes,1,"categorical");
                    
                    loopNum = loopNum+1;
                end
                totalPredictedLabel((idx-1)*testDataAmount+1:idx*testDataAmount,1) = predictedLabels;
                totalLabel((idx-1)*testDataAmount+1:idx*testDataAmount,1) = labels;
            end
            %====================================================================================
            result = TrainResult(nets,obj.train.conditionStrings,obj.train.labelStrings,totalPredictedLabel ,totalLabel);
            %結果の保存
            dirName = append(deepNetSavePath.path,obj.netSaveDirectory);
            if not(exist( dirName ,'dir'))
                mkdir( dirName )
            end
            accuracy = sum(totalPredictedLabel==totalLabel)./testDataAmount;
            commentAndData = append("Accuracy: ",string(accuracy));
            fileName = append(dirName,"accuracy.txt");
            writelines(commentAndData,fileName,WriteMode="append");
            save(append(dirName,obj.netSaveName),'result')
        end
        
        %==================================================================
        % カスタム損失関数による訓練起動 (マルチモーダル特化)
        %==================================================================
        function result = customLossFuncForMultimodalActivate(obj, trainActivator, labelOutPutLayerName,lossFunc,dirName)
            arguments
                obj TrainActivatorWave
                trainActivator TrainActivatorWave
                labelOutPutLayerName string
                lossFunc 
                dirName string
            end
            
            net = dlnetwork(obj.layerSetting); 
            nets = cell(1,obj.trainOption.trainRepeatAmount);
            %オプションを拾ってくる============================
            maxEpochs= obj.trainOption.option.MaxEpochs;
            gradientThreshold = obj.trainOption.option.GradientThreshold;
            frequency = obj.trainOption.option.ValidationFrequency;
            stopNumber = obj.trainOption.option.ValidationPatience;
            miniBatchSize = obj.trainOption.option.MiniBatchSize;

            stopNumber = 100;

            %===================================================
            %ここから訓練=======================================================================
            repeatAmount = obj.trainOption.trainRepeatAmount;
            classes = categories(categorical(obj.train.labelStrings));
            for i = 1:repeatAmount
                trailingAvg = [];
                trailingAvgSq = [];
                numIterationsPerEpoch = ceil(numel(obj.train.data) / miniBatchSize);
                maxIterations = maxEpochs * numIterationsPerEpoch;
                monitor = trainingProgressMonitor;
                monitor.Info = ["Epoch","Iteration"];
                monitor.Metrics = ["TrainingLoss","ValidationLoss","TrainingAccuracy","ValidationAccuracy"];
                monitor.XLabel = "反復";
                groupSubPlot(monitor,"精度(%)",["TrainingAccuracy","ValidationAccuracy"]);
                groupSubPlot(monitor,"損失",["TrainingLoss","ValidationLoss"]);
                epoch = 0;
                iteration = 0;
                minimumValidationLoss = Inf;
                shouldStopCount = 0;
                isStopped = false;
                
                % trainActivator のインスタンスから呼び出し
                mbq = trainActivator.createMiniBatchQueueOf_verMultimodal(obj.train);
                
                validationData = obj.trainOption.option.ValidationData{1};
                validationLabel = obj.trainOption.option.ValidationData{2};
                
                % trainActivator のインスタンスから呼び出し
                validationMbq = trainActivator.createValidationMiniBatchOf_verMultimodal(validationData, validationLabel);
                
                shuffle(validationMbq);
                while epoch < maxEpochs && ~monitor.Stop && ~isStopped
                    epoch = epoch + 1;
                    % シャッフル
                    shuffle(mbq)
                    %ミニバッチをまわし切って1-epoch
                    while hasdata(mbq) && ~monitor.Stop
                        iteration = iteration + 1;
                        [trainData,label] = next(mbq);
                        [loss,gradients,state] = dlfeval(lossFunc(labelOutPutLayerName),net,trainData,label);
                        net.State = state;
                        gradients = dlupdate(@(g) thresholdL2Norm(g, gradientThreshold),gradients);%勾配クリップ.
                        % adamを使ってネットワーク更新
                        [net,trailingAvg,trailingAvgSq] = adamupdate(net,gradients, trailingAvg,trailingAvgSq,iteration);
                        
                        % ★ 修正 1: 訓練データに対する精度計算を毎イテレーションで実行
                        predictedLabel =  predict(net,trainData,Outputs=[labelOutPutLayerName]);
                        classes = categories(categorical(obj.train.labelStrings)); % クラスをここで再定義（ループ外で定義済みだが安全のため）
                        accuracy = 100*sum(onehotdecode(predictedLabel,classes,1)==onehotdecode(label,classes,1))/miniBatchSize;
                        
                        
                        % 検証 (Validation)
                        if(mod(iteration,frequency)==0|| iteration==1)
                            if(~hasdata(validationMbq))
                                shuffle(validationMbq);
                            end
                            [validationTrainData, validationLabel] = next(validationMbq);
                            %精度確認
                            % TrainingAccuracyの計算は上で行うためここでは省略
                            validationPredictedLabel =  predict(net,validationTrainData,Outputs=[labelOutPutLayerName]);
                            decodeValidationPredictedLabel = onehotdecode(validationPredictedLabel , classes,1,"categorical");
                            decodeValidationLabel = onehotdecode(validationLabel,classes,1,"categorical");
                            validationAccuracy = 100*sum(decodeValidationPredictedLabel==decodeValidationLabel)/miniBatchSize;
                            [validationLoss,~,~] = dlfeval(lossFunc(labelOutPutLayerName),net,validationTrainData, validationLabel);
                            if(validationLoss>minimumValidationLoss)
                                shouldStopCount = shouldStopCount+1 ;
                            else
                                shouldStopCount = 0;
                                minimumValidationLoss = validationLoss;
                            end
                            if(shouldStopCount > stopNumber)
                                isStopped = true;
                                break;
                            end
                        end
                        % プロセスモニターの更新.
                        updateInfo(monitor, ...
                            Epoch=string(epoch) + " of " + string(maxEpochs), ...
                            Iteration=string(iteration) + " of " + string(maxIterations));
                        
                        % ★ 修正 2: 訓練データの結果をfrequencyの外側で記録 (Validationの結果はifブロック内で更新される)
                        recordMetrics(monitor,iteration, ...
                            TrainingAccuracy=accuracy, ...
                            ValidationAccuracy=validationAccuracy); % ValidationAccuracyはfrequency外では古い値を使用
                        recordMetrics(monitor,iteration, ...
                            TrainingLoss=loss, ...
                            ValidationLoss=validationLoss); % ValidationLossはfrequency外では古い値を使用
                        
                        monitor.Progress = 100*iteration/maxIterations;
                    end
                    
                end
                obj.saveCustomDeepMonitor(dirName,i);

                % ==========================================================
                % ★★★ 最終の繰り返しのみグラフを保存・終了処理を削除 ★★★
                % ==========================================================
                if i == repeatAmount
                    
                    % 1. Figureハンドルを取得 (findallを使用する修正案Bを適用)
                    %    ※ この処理は、ウィンドウが閉じないことを確認するために残します。
                    fig = findall(0, 'Type', 'figure', 'Name', '学習の進行状況');
                    
                    if isempty(fig)
                        fig = findall(0, 'Type', 'figure', 'Name', 'Training Progress');
                    end

                    if ~isempty(fig)
                        % 2. グラフの自動保存処理を削除
                        % saveas(fig, graphFileName);
                        
                        % 3. Figureを閉じる処理を削除
                        % close(fig); 

                        disp('最終学習進行状況のウィンドウは閉じません。手動でスクリーンショットを撮るか確認してください。');

                    else
                        warning('学習進行状況の Figure ウィンドウが見つかりませんでした。');
                    end
                end
                % ==========================================================

                nets{i} = net;
            end
            %====================================================================================
            %ここからテスト======================================================================
            % trainActivator のインスタンスから呼び出し
            mbqTest = trainActivator.createMiniBatchQueueOf_verMultimodal(obj.test);
            
            %minibatchに中途半端なものは捨てろと命令しているため, testDataAmountは正確には総出力の量と不一致.
            roughTestDataAmount = length(obj.test.data);
            testDataAmount = fix(roughTestDataAmount/miniBatchSize)*miniBatchSize;
            
            predictedLabels =strings(testDataAmount,1);
            labels = strings(testDataAmount,1);
            
            totalPredictedLabel = strings(testDataAmount*repeatAmount,1);
            totalLabel = strings(testDataAmount*repeatAmount,1);
           
            for idx = 1:repeatAmount
                reset(mbqTest);
                loopNum = 1;
                while hasdata(mbqTest)
                    % ミニバッチからデータ引き出し
                    [testData,label] = next(mbqTest);
                    predictedLabel = predict(nets{idx},testData,Outputs=[labelOutPutLayerName]);
                    predictedLabel = extractdata(gather(predictedLabel)); 
                    predictedLabels((loopNum-1)*miniBatchSize+1:loopNum*miniBatchSize) = onehotdecode(predictedLabel,classes,1,"categorical");
                    labelBatch = extractdata(gather(label));
                    labels((loopNum-1)*miniBatchSize+1:loopNum*miniBatchSize) = onehotdecode(labelBatch,classes,1,"categorical");
                    
                    loopNum = loopNum+1;
                end
                totalPredictedLabel((idx-1)*testDataAmount+1:idx*testDataAmount,1) = predictedLabels;
                totalLabel((idx-1)*testDataAmount+1:idx*testDataAmount,1) = labels;
            end
            %====================================================================================
            %====================================================================================
            result = TrainResult(nets,obj.train.conditionStrings,obj.train.labelStrings,totalPredictedLabel ,totalLabel);
            
            % ★ 修正ブロックの開始: 関数引数として渡された dirName を使用する ★
            
            % 1. ファイル名結合のためのパス区切り文字を確実に挿入 (Windows/Linux対応)
            %    (注意: ここでの dirName は関数引数として渡された値です)
            if dirName(end) ~= filesep
                dirName = append(dirName, filesep);
            end

            % 2. ディレクトリの存在を確認し、なければ作成する
            if not(exist( dirName ,'dir'))
                [success, message] = mkdir( dirName );
                if ~success
                   warning('ディレクトリを作成できませんでした: %s', message);
                   return; % ディレクトリ作成失敗の場合は処理を中止
                end
            end

            accuracy = sum(totalPredictedLabel==totalLabel)./testDataAmount;
            commentAndData = append("Accuracy: ",string(accuracy));
            
            % 3. 修正された dirName を使用してファイル名を生成し、書き込む
            fileName = append(dirName,"accuracy.txt");
            
            writelines(commentAndData,fileName,WriteMode="append");
            save(append(dirName,obj.netSaveName),'result')
        end
        
        %==================================================================
        % 通常の trainNetwork による訓練起動
        %==================================================================
        function result = activate(obj,dirName)
            arguments
                obj TrainActivatorWave
                dirName string
            end
            nets = cell(1,obj.trainOption.trainRepeatAmount);
            minimumLength = obj.test.minimumLength;
            repeatAmount = obj.trainOption.trainRepeatAmount;
            conditionLength = length(obj.train.conditionStrings);
            allPrediction = strings(minimumLength*repeatAmount*conditionLength,1);
            allTest = strings(minimumLength*repeatAmount*conditionLength,1);
            for i = 1:obj.trainOption.trainRepeatAmount
                net = trainNetwork(obj.train.data,obj.train.label,obj.layerSetting, obj.trainOption.option);
                prediction = classify(net,obj.test.data);
                acc=sum(prediction==obj.test.label)./numel(obj.test.label);
                allPrediction(1+(i-1)*minimumLength*conditionLength:i*minimumLength*conditionLength) = prediction;
                allTest(1+(i-1)*minimumLength*conditionLength:i*minimumLength*conditionLength) = obj.test.label;
                obj.saveAllTrainPlot(dirName,i);
                disp(acc);
                nets{i} = net;
            end
            allPrediction = categorical(allPrediction);
            allTest = categorical(allTest);
            result = TrainResult(nets,obj.train.conditionStrings,obj.train.labelStrings,allPrediction,allTest);
            %結果の保存
            dirName = append(deepNetSavePath.path,obj.netSaveDirectory);
            if not(exist( dirName ,'dir'))
                mkdir( dirName )
            end
            save(append(dirName,obj.netSaveName),'result')
        end
        
        %==================================================================
        % 通常の trainNetwork による訓練起動 (マルチモーダル特化)
        %==================================================================
        function result = activateMultimodal(obj, trainActivator, dirName)
            arguments
                obj TrainActivatorWave
                trainActivator TrainActivatorWave
                dirName string
            end
            nets = cell(1,trainActivator.trainOption.trainRepeatAmount);
            minimumLength = trainActivator.test.minimumLength;
            repeatAmount = trainActivator.trainOption.trainRepeatAmount;
            conditionLength = length(trainActivator.train.conditionStrings);
            allPrediction = strings(minimumLength*repeatAmount*conditionLength,1);
            allTest = strings(minimumLength*repeatAmount*conditionLength,1);
            for i = 1:trainActivator.trainOption.trainRepeatAmount
                net = trainNetwork(trainActivator.train.data,trainActivator.train.label,trainActivator.layerSetting,trainActivator.trainOption.option);
                prediction = classify(net,trainActivator.test.data);
                acc=sum(prediction == trainActivator.test.label)./numel(trainActivator.test.label);
                allPrediction(1+(i-1)*minimumLength*conditionLength:i*minimumLength*conditionLength) = prediction;
                allTest(1+(i-1)*minimumLength*conditionLength:i*minimumLength*conditionLength) = trainActivator.test.label;
                trainActivator.saveAllTrainPlot(dirName,i);
                disp(acc);
                nets{i} = net;
            end
            allPrediction = categorical(allPrediction);
            allTest = categorical(allTest);
            result = TrainResult(nets,trainActivator.train.conditionStrings,trainActivator.train.labelStrings,allPrediction,allTest);
            %結果の保存
            dirName = append(deepNetSavePath.path,trainActivator.netSaveDirectory);
            if not(exist( dirName ,'dir'))
                mkdir( dirName )
            end
            save(append(dirName,trainActivator.netSaveName),'result')
        end
    end

methods (Access = private)
        
        %==================================================================
        % ミニバッチキュー作成 (マルチモーダル/波形用)
        %==================================================================
        function [mbq] = createMiniBatchQueueOf_verMultimodal(obj, trainTestData)
            arguments
                obj TrainActivatorWave
                trainTestData TrainTestDataWave
            end
            %オプションを拾ってくる============================
            miniBatchSize = obj.trainOption.option.MiniBatchSize;
            inputSize = size(trainTestData.data{1},1);
            %==================================================
            vanillaTrainDataStore = arrayDatastore(trainTestData.data,"ReadSize", miniBatchSize, "OutputType", "same");
            LabelStore = arrayDatastore(trainTestData.label,"ReadSize", miniBatchSize);
            trainDataStore = combine(vanillaTrainDataStore,LabelStore);
            mbq = minibatchqueue(trainDataStore,...
                PartialMiniBatch='discard',...
                MiniBatchSize=miniBatchSize,...
                MiniBatchFcn=@preprocessFlowData,...
                MiniBatchFormat=["CTB", "" ]); 
        end
        
        function [validationMbq] = createValidationMiniBatchOf_verMultimodal(obj, data,label)
            arguments
                obj TrainActivatorWave
                data (:,1) cell
                label (:,:) categorical
            end
             %オプションを拾ってくる============================
            miniBatchSize = obj.trainOption.option.MiniBatchSize;
            inputSize = size(data{1},1);
            %==================================================
            
            vanillaTrainDataStore = arrayDatastore(data,"ReadSize",miniBatchSize, "OutputType","same");
            LabelStore = arrayDatastore(label,"ReadSize",miniBatchSize);
            validationDataStore = combine(vanillaTrainDataStore,LabelStore);
            validationMbq = minibatchqueue(validationDataStore,...
                PartialMiniBatch='discard',...
                MiniBatchSize=miniBatchSize, ...
                MiniBatchFcn=@preprocessFlowData, ...
                MiniBatchFormat=["CTB", "" ]); 
        end
        
        %==================================================================
        % プロット保存用のプライベートメソッド
        %==================================================================
        function [] = saveCustomDeepMonitor(obj,folderName,testNumber)
            arguments
                obj TrainActivatorWave
                folderName string
                testNumber {mustBeNumeric}
            end
            dirName = append(PictureSavePath.path,folderName);
            if not(exist( dirName ,'dir'))
                mkdir( dirName )
            end
            trainPlot = findall(groot, 'Tag', 'DEEPMONITOR_UIFIGURE');
            trainPlotLength = length(trainPlot);
            for i = 1: trainPlotLength
                savefig(trainPlot(i), append(dirName, append("trainPlot",string(testNumber ),".fig")));
                close(trainPlot(i));
            end
        end
        function [] = saveAllTrainPlot(obj,folderName,testNumber)
            %学習推移の保存
            arguments
                obj TrainActivatorWave
                folderName string
                testNumber {mustBeNumeric}
            end
            dirName = append(PictureSavePath.path,folderName);
            if not(exist( dirName ,'dir'))
                mkdir( dirName )
            end
            isNewer2021B = false;
            trainPlot = findall(groot, 'Tag', 'NNET_CNN_TRAININGPLOT_FIGURE');
            if isempty(trainPlot)
                trainPlot = findall(groot, 'Tag', 'NNET_CNN_TRAININGPLOT_UIFIGURE');
                isNewer2021B = true;
            end
            trainPlotLength = length(trainPlot);
            for i = 1: trainPlotLength
                %matlab 2021bだとタグの名前が変化している.
                if isNewer2021B
                    savefig(trainPlot(i), append(dirName, append("trainPlot",string(testNumber ),".fig")));
                    close(trainPlot(i));
                else
                    saveas(trainPlot(i), append( dirName , append("trainPlot",string(testNumber ),".png")));
                    close(trainPlot(i));
                end
            end
        end
    end
end
