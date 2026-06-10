classdef TrainActivator
    %UNTITLED 学習器を起動する
    %   詳細説明をここに記述

    properties (SetAccess = immutable)
        train TrainTestData
        test TrainTestData
        trainOption TrainOption
        layerSetting
        netSaveName string
        netSaveDirectory string
    end

    methods (Access = public)
        function obj = TrainActivator(train,test, option, layer,varAndName)
            arguments
                train TrainTestData
                test TrainTestData
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
        
        function result = customLossFuncActivate(obj, labelOutPutLayerName,lossFunc,dirName)
            arguments
                obj TrainActivator
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

                mbq = obj.createMiniBatchQueueOf(obj.train);
                validationData = obj.trainOption.option.ValidationData{1};
                validationLabel = obj.trainOption.option.ValidationData{2};
                validationMbq = obj.createValidationMiniBatchOf(validationData, validationLabel);
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
                            %精度確認 onehotdecodeで, デコードであってエンコードではないことに注意. 見づらいけど.
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
            mbqTest = obj.createMiniBatchQueueOf(obj.test);
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

                    predictedLabel = extractdata(gather(predictedLabel)); % gatherしないと, gpuArray型のまま. ブレークすれば分かるがここのpredictedはミニバッチだけの長さがあることに注意. 
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

        function result = customLossFuncForMultimodalActivate(obj, trainActivator, labelOutPutLayerName,lossFunc,dirName)
            arguments
                obj TrainActivator
                trainActivator TrainActivator
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

                mbq = obj.createMiniBatchQueueoOf_verMultimodal(trainActivator, obj.train);
                validationData = obj.trainOption.option.ValidationData{1};
                validationLabel = obj.trainOption.option.ValidationData{2};
                validationMbq = obj.createValidationMiniBatchOf_verMultimodal(trainActivator, validationData, validationLabel);
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
                            %精度確認 onehotdecodeで, デコードであってエンコードではないことに注意. 見づらいけど.
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
            mbqTest = obj.createMiniBatchQueueOf(obj.test);
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

                    predictedLabel = extractdata(gather(predictedLabel)); % gatherしないと, gpuArray型のまま. ブレークすれば分かるがここのpredictedはミニバッチだけの長さがあることに注意. 
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


        function result = activate(obj,dirName)
            arguments
                obj TrainActivator
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

        function result = activateMultimodal(obj, trainActivator, dirName)
            arguments
                obj TrainActivator
                trainActivator TrainActivator
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


        function [mbq] = createMiniBatchQueueOf(obj,trainTestData)
            arguments
                obj TrainActivator
                trainTestData TrainTestData
            end
            %オプションを拾ってくる============================
            miniBatchSize = obj.trainOption.option.MiniBatchSize;
            inputSize = size(trainTestData.data{1},1);
            %==================================================
            vanillaTrainDataStore = arrayDatastore(cell2mat(trainTestData.data),"ReadSize",inputSize);
            LabelStore = arrayDatastore(trainTestData.label,"ReadSize",1);
            trainDataStore = combine(vanillaTrainDataStore,LabelStore);

            mbq = minibatchqueue(trainDataStore,...
                OutputCast='double',...
                PartialMiniBatch='discard',...
                MiniBatchSize=miniBatchSize,...
                MiniBatchFcn=@preprocessFlowData,...
                MiniBatchFormat=["CTB" "" ]);
        end

        function [validationMbq] = createValidationMiniBatchOf(obj,data,label)
            arguments
                obj TrainActivator
                data (:,1) cell
                label (:,1) categorical
            end
             %オプションを拾ってくる============================
            miniBatchSize = obj.trainOption.option.MiniBatchSize;
            inputSize = size(data{1},1);
            %==================================================

            vanillaTrainDataStore = arrayDatastore(cell2mat(data),"ReadSize",inputSize);
            LabelStore = arrayDatastore(label,"ReadSize",1);
            validationDataStore = combine(vanillaTrainDataStore,LabelStore);

            validationMbq = minibatchqueue(validationDataStore,...
                OutputCast='double',...
                PartialMiniBatch='discard',...
                MiniBatchSize=miniBatchSize,...
                MiniBatchFcn=@preprocessFlowData,...
                MiniBatchFormat=["CTB" "" ]);
        end

        function [mbq] = createMiniBatchQueueoOf_verMultimodal(obj,trainActivator, trainTestData)
            arguments
                obj TrainActivator
                trainActivator TrainActivator
                trainTestData TrainTestData
            end
            %オプションを拾ってくる============================
            miniBatchSize = trainActivator.trainOption.option.MiniBatchSize;
            inputSize = size(trainTestData.data{1},1);
            %==================================================
            vanillaTrainDataStore = arrayDatastore(cell2mat(trainTestData.data),"ReadSize",inputSize);
            LabelStore = arrayDatastore(trainTestData.label,"ReadSize",2);
            trainDataStore = combine(vanillaTrainDataStore,LabelStore);

            mbq = minibatchqueue(trainDataStore,...
                OutputCast='double',...
                PartialMiniBatch='discard',...
                MiniBatchSize=miniBatchSize,...
                MiniBatchFcn=@preprocessFlowData,...
                MiniBatchFormat=["CTB" "" ]);
        end

        function [validationMbq] = createValidationMiniBatchOf_verMultimodal(obj,trainActivator, data,label)
            arguments
                obj TrainActivator
                trainActivator TrainActivator
                data (:,1) cell
                label (:,:) categorical
            end
             %オプションを拾ってくる============================
            miniBatchSize = trainActivator.trainOption.option.MiniBatchSize;
            inputSize = size(data{1},1);
            %==================================================

            vanillaTrainDataStore = arrayDatastore(cell2mat(data),"ReadSize",inputSize);
            LabelStore = arrayDatastore(label,"ReadSize",2);
            validationDataStore = combine(vanillaTrainDataStore,LabelStore);

            validationMbq = minibatchqueue(validationDataStore,...
                OutputCast='double',...
                PartialMiniBatch='discard',...
                MiniBatchSize=miniBatchSize,...
                MiniBatchFcn=@preprocessFlowData,...
                MiniBatchFormat=["CTB" "" ]);
        end

        function [] = saveCustomDeepMonitor(obj,folderName,testNumber)
            arguments
                obj TrainActivator
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
                obj TrainActivator
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

