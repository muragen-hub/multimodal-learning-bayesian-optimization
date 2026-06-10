classdef TrainTestDataCreatorTwo

    methods(Access = public)
        function obj = TrainTestDataCreatorTwo()
        end

        function [train, test] = createNormalData(obj, trainFormattedDataArray, testFormattedDataArray)
            %trainFormattedData, testFormattedData共に訓練, テストデータのしたいデータの配列.
            arguments
                obj TrainTestDataCreatorTwo
                trainFormattedDataArray (1,:) FormattedDataTwo
                testFormattedDataArray (1,:) FormattedDataTwo
            end
            [trainData, trainLabel, trainDataMinimumAmount,testData, testLabel, testDataMinimumAmount] = obj.createNormalDataCore(trainFormattedDataArray,testFormattedDataArray);

            % formatは訓練側, テスト側で全て同じになるようにされていると仮定する.
            condition = trainFormattedDataArray(1).condition;
            label = trainFormattedDataArray(1).label;
            conditionLength = length(condition);
            
            % machineLearningCell の内容から特徴量次元を動的に決定
            dataWidth = size(trainData{1}, 2);
            inputSize = size(trainData{1}, 3);

            % 1 * 流量条件個数のcell配列からdataWidthのデータの最小の個数*流量条件個数 * dataWidthに変更
            bundledTrainData=zeros(trainDataMinimumAmount*conditionLength, dataWidth,inputSize);
            bundledTrainLabel=strings(trainDataMinimumAmount*conditionLength,1);
            bundledTestData=zeros(testDataMinimumAmount*conditionLength, dataWidth,inputSize);
            bundledTestLabel=strings(testDataMinimumAmount*conditionLength,1);

            for i=1:conditionLength
                bundledTrainData((i-1)*trainDataMinimumAmount+1: i*trainDataMinimumAmount, :,:) = trainData{i};
                bundledTrainLabel((i-1)*trainDataMinimumAmount+1: i*trainDataMinimumAmount, :) = trainLabel{i};

                bundledTestData((i-1)*testDataMinimumAmount+1: i*testDataMinimumAmount, :,:) = testData{i};
                bundledTestLabel((i-1)*testDataMinimumAmount+1: i*testDataMinimumAmount, :) = testLabel{i};
            end
            bundledTrainLabel = categorical(bundledTrainLabel);
            bundledTestLabel = categorical(bundledTestLabel);

             % 再びセルに
            bundledTrainData = num2cell(bundledTrainData,[2 3]);
            bundledTestData = num2cell(bundledTestData,[2 3]);
            
            % 例えば, 各セル内の1*300*3ベクトルを3*300ベクトルへ変更する.
            bundledTrainData =  cellfun(@(x) permute(x,[3,2,1]), bundledTrainData,'uniformOutput',false);
            bundledTestData = cellfun(@(x) permute(x,[3,2,1]), bundledTestData,'uniformOutput',false);
        
            % 次元の削除
            bundledTrainData =  cellfun(@(x) squeeze(x), bundledTrainData,'uniformOutput',false);
            bundledTestData = cellfun(@(x) squeeze(x), bundledTestData,'uniformOutput',false);

            % labelは最後に結合する．
            trainLabels = [];
            for ii = 1:length(trainFormattedDataArray)
                trainLabels = [trainLabels trainFormattedDataArray(ii).label]; %#ok 
            end
            testLabels = [];
            for ii = 1:length(testFormattedDataArray)
                testLabels = [testLabels, testFormattedDataArray(ii).label]; %#ok
            end
            testLabels = unique(testLabels);

            train = TrainTestData(bundledTrainData,bundledTrainLabel,trainDataMinimumAmount,condition,trainLabels);
            test = TrainTestData(bundledTestData, bundledTestLabel,testDataMinimumAmount,condition,testLabels);

            clear trainData trainLabel testData testLabel;
        end

        function [train, test] = createSeqToSeqRegressionData(obj, trainFormattedDataArray, testFormattedDataArray)
            %seq-to-seqを使う時はこちらの関数を使う. 
            arguments
                obj TrainTestDataCreatorTwo
                trainFormattedDataArray (1,:) FormattedDataTwo
                testFormattedDataArray (1,:) FormattedDataTwo
            end
             [trainData, trainLabel, trainDataMinimumAmount,testData, testLabel, testDataMinimumAmount,trainAccurateLiquidFlowRate, trainAccurateGasFlowRate,testAccurateLiquidFlowRate, testAccurateGasFlowRate]...
                 = obj.createNormalDataCoreWithAccurateFlowRate(trainFormattedDataArray,testFormattedDataArray);
             % formatは訓練側, テスト側で全て同じになるようにされていると仮定する.
            condition = trainFormattedDataArray(1).condition;
            label = trainFormattedDataArray(1).label;
            conditionLength = length(condition);
            
            % machineLearningCell の内容から特徴量次元を動的に決定
            % dataWidth = trainFormattedDataArray(1).option.dataWidth; % DataFormatterTwoで結合後のサイズは変わる可能性があるため、trainData{1}から取得するのが安全だが、ここでは仮にそのまま
            dataWidth = size(trainData{1}, 2);
            inputSize = size(trainData{1},3);

             % seq-to-seq用に一つずらした300点ベクトルが必要なため, ここで最後のデータを切り捨てる. 
            trainDataMinimumAmount = trainDataMinimumAmount-1;
            testDataMinimumAmount = testDataMinimumAmount-1;
            
            %シーケンスの個数が1と決まっているもの. 
            bundledTrainLabel=strings(trainDataMinimumAmount*conditionLength,1);
            bundledTrainAccurateLiquidFlowRate = zeros(trainDataMinimumAmount*conditionLength,1);
            bundledTrainAccurateGasFlowRate = zeros(trainDataMinimumAmount*conditionLength,1);

            bundledTestLabel=strings(testDataMinimumAmount*conditionLength,1);
            bundledTestAccurateLiquidFlowRate = zeros(testDataMinimumAmount*conditionLength,1);
            bundledTestAccurateGasFlowRate = zeros(testDataMinimumAmount*conditionLength,1);
            
            %複数シーケンスあるかもしれないもの. ValueLabelとは, 回帰のseq-to-seq用の教師データのことをさす. 
            bundledTrainData = zeros(trainDataMinimumAmount*conditionLength,dataWidth,inputSize);
            bundledTrainValueLabel = zeros(trainDataMinimumAmount*conditionLength,dataWidth,inputSize);

            bundledTestData = zeros(testDataMinimumAmount*conditionLength,dataWidth,inputSize);
            bundledTestValueLabel = zeros(testDataMinimumAmount*conditionLength,dataWidth,inputSize);
            
            %丁寧に作った枠に入れていく
            for idx=1:conditionLength
                bundledTrainData((idx-1)*trainDataMinimumAmount+1:idx*trainDataMinimumAmount,:,:) = trainData{idx}(1:end-1,:,:);
                % 教師データ (一つずらし)
                bundledTrainValueLabel((idx-1)*trainDataMinimumAmount+1:idx*trainDataMinimumAmount,:,:) = cat(2,trainData{idx}(1:end-1,2:end,:),trainData{idx}(2:end,1,:));
                
                bundledTrainLabel((idx-1)*trainDataMinimumAmount +1: idx*trainDataMinimumAmount, :) = trainLabel{idx}(1:end-1);
                bundledTrainAccurateLiquidFlowRate((idx-1)*trainDataMinimumAmount +1: idx*trainDataMinimumAmount, :) = trainAccurateLiquidFlowRate{idx}(1:end-1,1);
                bundledTrainAccurateGasFlowRate((idx-1)*trainDataMinimumAmount +1: idx*trainDataMinimumAmount, :) = trainAccurateGasFlowRate{idx}(1:end-1,1);

                bundledTestData((idx-1)*testDataMinimumAmount+1:idx*testDataMinimumAmount,:,:) = testData{idx}(1:end-1,:,:);
                % 教師データ (一つずらし)
                bundledTestValueLabel((idx-1)*testDataMinimumAmount+1:idx*testDataMinimumAmount,:,:) = cat(2,testData{idx}(1:end-1,2:end,:),testData{idx}(2:end,1,:));
                
                bundledTestLabel((idx-1)*testDataMinimumAmount +1: idx*testDataMinimumAmount , :) = testLabel{idx}(1:end-1);
                bundledTestAccurateLiquidFlowRate((idx-1)*testDataMinimumAmount +1: idx*testDataMinimumAmount, :) = testAccurateLiquidFlowRate{idx}(1:end-1,1);
                bundledTestAccurateGasFlowRate((idx-1)*testDataMinimumAmount +1: idx*testDataMinimumAmount, :) = testAccurateGasFlowRate{idx}(1:end-1,1); 
            end
            % メモリ節約
            clear trainData trainLabel testData testLabel;
            
            bundledTestLabel = categorical(bundledTestLabel);
            bundledTrainLabel = categorical(bundledTrainLabel);
            
            % 再びセルに
            bundledTrainData = num2cell(bundledTrainData,[2 3]);
            bundledTrainValueLabel = num2cell(bundledTrainValueLabel,[2 3]);
            bundledTestData = num2cell(bundledTestData,[2 3]);
            bundledTestValueLabel = num2cell(bundledTestValueLabel,[2 3]);
            
            % 例えば, 各セル内の1*300*3ベクトルを3*300ベクトルへ変更する.
            bundledTrainData =  cellfun(@(x) permute(x,[3,2,1]), bundledTrainData,'uniformOutput',false);
            bundledTestData = cellfun(@(x) permute(x,[3,2,1]), bundledTestData,'uniformOutput',false);
            bundledTrainValueLabel = cellfun(@(x) permute(x,[3,2,1]), bundledTrainValueLabel,'uniformOutput',false);
            bundledTestValueLabel = cellfun(@(x) permute(x,[3,2,1]), bundledTestValueLabel,'uniformOutput',false);
            
            % 次元の削除
            bundledTrainData =  cellfun(@(x) squeeze(x), bundledTrainData,'uniformOutput',false);
            bundledTestData = cellfun(@(x) squeeze(x), bundledTestData,'uniformOutput',false);
            bundledTrainValueLabel = cellfun(@(x) squeeze(x), bundledTrainValueLabel,'uniformOutput',false);
            bundledTestValueLabel = cellfun(@(x) squeeze(x), bundledTestValueLabel,'uniformOutput',false);

            train = RegressionTrainTestData(bundledTrainData,bundledTrainValueLabel ,bundledTrainLabel,trainDataMinimumAmount,condition,label,bundledTrainAccurateLiquidFlowRate,bundledTrainAccurateGasFlowRate);
            test = RegressionTrainTestData(bundledTestData,bundledTestValueLabel ,bundledTestLabel,testDataMinimumAmount,condition,label,bundledTestAccurateLiquidFlowRate,bundledTestAccurateGasFlowRate);
        end

        function [train, test] = createRegressionData(obj, trainFormattedDataArray, testFormattedDataArray)
            %seq-to-Seqは色々なものを壊すのでこの関数では扱わない. 
            arguments
                obj TrainTestDataCreatorTwo
                trainFormattedDataArray (1,:) FormattedDataTwo
                testFormattedDataArray (1,:) FormattedDataTwo
            end
            if(isempty(trainFormattedDataArray(1).liquidFlowRateOfEachData))
                error("回帰用ならば必ず正確な流量も入れてください. createWithFlowRate関数を使ってrawDataクラスを作ってください")
            end
            [trainData, trainLabel, trainDataMinimumAmount,testData, testLabel, testDataMinimumAmount,trainAccurateLiquidFlowRate, trainAccurateGasFlowRate,testAccurateLiquidFlowRate, testAccurateGasFlowRate]...
                = obj.createNormalDataCoreWithAccurateFlowRate(trainFormattedDataArray,testFormattedDataArray);
            % formatは訓練側, テスト側で全て同じになるようにされていると仮定する.
            condition = trainFormattedDataArray(1).condition;
            label = trainFormattedDataArray(1).label;
            conditionLength = length(condition);
            
            % machineLearningCell の内容から特徴量次元を動的に決定
            dataWidth = size(trainData{1}, 2);
            inputSize = size(trainData{1},3);
            
            %シーケンスの個数が1と決まっているもの. 
            bundledTrainLabel=strings(trainDataMinimumAmount*conditionLength,1);
            bundledTrainAccurateLiquidFlowRate = zeros(trainDataMinimumAmount*conditionLength,1);
            bundledTrainAccurateGasFlowRate = zeros(trainDataMinimumAmount*conditionLength,1);

            bundledTestLabel=strings(testDataMinimumAmount*conditionLength,1);
            bundledTestAccurateLiquidFlowRate = zeros(testDataMinimumAmount*conditionLength,1);
            bundledTestAccurateGasFlowRate = zeros(testDataMinimumAmount*conditionLength,1);
            
            %複数シーケンスあるかもしれないもの. ValueLabelとは, 回帰のseq-to-seq用の教師データのことをさす. 
            bundledTrainData = zeros(trainDataMinimumAmount*conditionLength,dataWidth,inputSize);
            bundledTrainValueLabel = cell(1); %seq-to-seqは別の関数で行う. 

            bundledTestData = zeros(testDataMinimumAmount*conditionLength,dataWidth,inputSize);
            bundledTestValueLabel = cell(1);
            
            %丁寧に作った枠に入れていく
            for idx=1:conditionLength
                bundledTrainData((idx-1)*trainDataMinimumAmount+1:idx*trainDataMinimumAmount,:,:) = trainData{idx}(1:end,:,:);
                
                bundledTrainLabel((idx-1)*trainDataMinimumAmount +1: idx*trainDataMinimumAmount, :) = trainLabel{idx}(1:end);
                bundledTrainAccurateLiquidFlowRate((idx-1)*trainDataMinimumAmount +1: idx*trainDataMinimumAmount, :) = trainAccurateLiquidFlowRate{idx}(1:end,1);
                bundledTrainAccurateGasFlowRate((idx-1)*trainDataMinimumAmount +1: idx*trainDataMinimumAmount, :) = trainAccurateGasFlowRate{idx}(1:end,1);

                bundledTestData((idx-1)*testDataMinimumAmount+1:idx*testDataMinimumAmount,:,:) = testData{idx}(1:end,:,:);
                
                bundledTestLabel((idx-1)*testDataMinimumAmount +1: idx*testDataMinimumAmount , :) = testLabel{idx}(1:end);
                bundledTestAccurateLiquidFlowRate((idx-1)*testDataMinimumAmount +1: idx*testDataMinimumAmount, :) = testAccurateLiquidFlowRate{idx}(1:end,1);
                bundledTestAccurateGasFlowRate((idx-1)*testDataMinimumAmount +1: idx*testDataMinimumAmount, :) = testAccurateGasFlowRate{idx}(1:end,1); 
            end
            % メモリ節約
            clear trainData trainLabel testData testLabel;
            
            bundledTestLabel = categorical(bundledTestLabel);
            bundledTrainLabel = categorical(bundledTrainLabel);
            
            % 再びセルに
            bundledTrainData = num2cell(bundledTrainData,[2 3]);
            bundledTestData = num2cell(bundledTestData,[2 3]);
            
            % 例えば, 各セル内の1*300*3ベクトルを3*300ベクトルへ変更する.
            bundledTrainData =  cellfun(@(x) permute(x,[3,2,1]), bundledTrainData,'uniformOutput',false);
            bundledTestData = cellfun(@(x) permute(x,[3,2,1]), bundledTestData,'uniformOutput',false);
            
            % 次元の削除
            bundledTrainData =  cellfun(@(x) squeeze(x), bundledTrainData,'uniformOutput',false);
            bundledTestData = cellfun(@(x) squeeze(x), bundledTestData,'uniformOutput',false);
            
            train = RegressionTrainTestData(bundledTrainData,bundledTrainValueLabel ,bundledTrainLabel,trainDataMinimumAmount,condition,label,bundledTrainAccurateLiquidFlowRate,bundledTrainAccurateGasFlowRate);
            test = RegressionTrainTestData(bundledTestData,bundledTestValueLabel ,bundledTestLabel,testDataMinimumAmount,condition,label,bundledTestAccurateLiquidFlowRate,bundledTestAccurateGasFlowRate);
        end

        function [train, test] = createMultiVectorData(obj, trainFormattedDataArray, testFormattedDataArray)
            arguments
                obj TrainTestDataCreatorTwo
                trainFormattedDataArray (1,:) FormattedDataTwo
                testFormattedDataArray (1,:) FormattedDataTwo
            end
            [trainData, trainLabel, trainDataMinimumAmount,testData, testLabel, testDataMinimumAmount] = obj.createNormalDataCore(trainFormattedDataArray,testFormattedDataArray);

            condition = trainFormattedDataArray(1).condition;
            label = trainFormattedDataArray(1).label;
            conditionLength = length(condition);

            % 1 * 流量条件個数のcell配列からdataWidthのデータの最小の個数*流量条件個数 * dataWidthに変更
            bundledTrainData= trainData{1};
            bundledTestData= testData{1};

            bundledTrainLabel=strings(trainDataMinimumAmount*conditionLength,1);
            bundledTestLabel=strings(testDataMinimumAmount*conditionLength,1);

            % ここのループ反復についてアテは気にしない
            %[Attention] 何故かvertcatでcellのcategorical列をつないでいくと,
            %'0'というカテゴリが入り, 学習中にsub2ind関数のout of indexエラーが出る.
            %見たい人はdbstackでスタックトレースを見て, idummify関数の周りを見よう.
            for i=2:conditionLength
                bundledTrainData = vertcat(bundledTrainData, trainData{i}); %#ok
                %bundledTrainLabel = vertcat(bundledTrainLabel, trainLabel{i});%#ok

                bundledTestData = vertcat(bundledTestData,testData{i});%#ok
                %bundledTestLabel = vertcat(bundledTestLabel, testLabel{i});%#ok
            end

            for i=1:conditionLength
                bundledTestLabel((i-1)*testDataMinimumAmount+1: i*testDataMinimumAmount, :) = testLabel{i};
                bundledTrainLabel((i-1)*trainDataMinimumAmount+1: i*trainDataMinimumAmount, :) = trainLabel{i};
            end

            bundledTestLabel = categorical(bundledTestLabel);
            bundledTrainLabel = categorical(bundledTrainLabel);

            bundledTrainData = num2cell(bundledTrainData,[2 3]);
            bundledTestData = num2cell(bundledTestData,[2 3]);

            %ここもっと賢いやり方があるはず, 各セル内の1*300*3ベクトルを3*300ベクトルへ変更する.
            bundledTrainData =  cellfun(@(x) permute(x,[3,2,1]), bundledTrainData,'uniformOutput',false);
            bundledTestData = cellfun(@(x) permute(x,[3,2,1]), bundledTestData,'uniformOutput',false);
            bundledTrainData =  cellfun(@(x) squeeze(x), bundledTrainData,'uniformOutput',false);
            bundledTestData = cellfun(@(x) squeeze(x), bundledTestData,'uniformOutput',false);

            train = TrainTestDataTwo(bundledTrainData,bundledTrainLabel,trainDataMinimumAmount,condition,label);
            test = TrainTestDataTwo(bundledTestData, bundledTestLabel,testDataMinimumAmount,condition,label);

            clear trainData trainLabel testData testLabel;
        end


        function [train, test] = createAndPreProcessMultimodalData(obj, trainFormattedDataArray, testFormattedDataArray, preProcessorFunc)
                arguments
                    obj TrainTestDataCreatorTwo
                    trainFormattedDataArray (1,:) FormattedDataTwo
                    testFormattedDataArray (1,:) FormattedDataTwo
                    preProcessorFunc
                end
                
                condition = trainFormattedDataArray(1).condition;
                label = trainFormattedDataArray(1).label;
                conditionLength = length(trainFormattedDataArray(1).condition);
                trainDataLength = length(trainFormattedDataArray);
                testDataLength = length(testFormattedDataArray);
                trainData=cell(1,conditionLength);
                trainLabel=cell(1,conditionLength);
                testData=cell(1,conditionLength);
                testLabel=cell(1,conditionLength);

        %各流量条件ごとにセル配列の中身に連ねていく.
        % ✅ 修正済み: machineLearningCell からデータ抽出
                for i_1=1:conditionLength
                        for j_1=1:trainDataLength
                                 trainData{j_1, i_1}=trainFormattedDataArray(j_1).machineLearningCell{i_1}; 
                                 trainLabel{j_1, i_1} = trainFormattedDataArray(j_1).labelCell{i_1};
                        end

                        for k_1 = 1: length(testFormattedDataArray)
                                 testData{k_1, i_1} = testFormattedDataArray(k_1).machineLearningCell{i_1}; 
                                 testLabel{k_1, i_1} = testFormattedDataArray(k_1).labelCell{i_1};
                        end
                end

                trainDataMinimumAmount = numel(trainData{1, 1}(:,1));

                for i_2 = 1:trainDataLength
                        for j_2 = 1:conditionLength
                                 if numel(trainData{i_2, j_2}(:,1)) < trainDataMinimumAmount
                                         trainDataMinimumAmount = numel(trainData{i_2, j_2}(:,1));
                                 end
                        end
                end
    
                for i_3 = 1:conditionLength
                        for j_3 = 1:trainDataLength
                                 if numel(trainData{j_3 , i_3}(:,1)) >= trainDataMinimumAmount
                                         idx = 1:trainDataMinimumAmount;
                                         trainData{j_3, i_3} = trainData{j_3, i_3}(idx, :, :);
                                         trainLabel{j_3, i_3} = trainLabel{j_3, i_3}(idx, :, :);
                                 end
                        end
                end

                testDataMinimumAmount = numel(testData{1, 1}(:,1));
        
                for i_4=1:conditionLength
                        for j_4 = 1:trainDataLength
                                 if numel(testData{j_4, i_4}(:,1))<testDataMinimumAmount
                                         testDataMinimumAmount=numel(testData{j_4, i_4}(:,1));
                                 end
                        end
                end
        
                for i_5 = 1:conditionLength
                        for j_5 = 1:trainDataLength
                                 if numel(testData{j_5 , i_5}(:,1)) >= testDataMinimumAmount
                                         idx = 1:testDataMinimumAmount;
                                         testData{j_5, i_5} = testData{j_5, i_5}(idx, :, :);
                                         testLabel{j_5, i_5} = testLabel{j_5, i_5}(idx, :, :);
                                 end
                        end
                end
                
                % machineLearningCell の内容からサイズを取得
                dataWidth = size(trainData{1,1}, 2); 
                inputSize = size(trainData{1,1},3);

                bundledTrainData=zeros(trainDataMinimumAmount*conditionLength, dataWidth,inputSize);
                bundledTrainLabel=strings(trainDataMinimumAmount*conditionLength,1);
                bundledTrainData_2 = zeros(trainDataMinimumAmount*conditionLength, dataWidth,inputSize);
                bundledTestData_2 = zeros(testDataMinimumAmount*conditionLength, dataWidth,inputSize);
                bundledTestData=zeros(testDataMinimumAmount*conditionLength, dataWidth,inputSize);
                bundledTestLabel=strings(testDataMinimumAmount*conditionLength,1);

                for i=1:conditionLength
                        bundledTrainData((i-1)*trainDataMinimumAmount+1: i*trainDataMinimumAmount, :,:) = trainData{1,i};
                        bundledTrainLabel((i-1)*trainDataMinimumAmount+1: i*trainDataMinimumAmount, :,:) = trainLabel{1,i};
                        bundledTrainData_2((i-1)*trainDataMinimumAmount+1: i*trainDataMinimumAmount, :,:) = trainData{2,i};
                        bundledTestData_2((i-1)*testDataMinimumAmount+1: i*testDataMinimumAmount, :,:) = testData{2,i};

                        bundledTestData((i-1)*testDataMinimumAmount+1: i*testDataMinimumAmount, :,:) = testData{1,i};
                        bundledTestLabel((i-1)*testDataMinimumAmount+1: i*testDataMinimumAmount, :,:) = testLabel{1,i};
                end

                bundledTrainLabel = categorical(bundledTrainLabel);
                bundledTestLabel = categorical(bundledTestLabel);

                % 再びセルに
                bundledTrainData = num2cell(bundledTrainData, [2 3]);
                bundledTestData = num2cell(bundledTestData, [2 3]);
                bundledTrainData_2 = num2cell(bundledTrainData_2, [2 3]);
                bundledTestData_2 = num2cell(bundledTestData_2, [2 3]);
                
                %preprocess
                trainTestPreProcessor = TrainTestPreProcessor(preProcessorFunc);
                [bundledTrainData, bundledTestData] = trainTestPreProcessor.cellInputProcess(bundledTrainData, bundledTestData);
                [bundledTrainData_2, bundledTestData_2] = trainTestPreProcessor.cellInputProcess(bundledTrainData_2, bundledTestData_2);
                
                trainDataSize = conditionLength * trainDataMinimumAmount;
                testDataSize = conditionLength * testDataMinimumAmount;

                for i = 1:trainDataSize
                        for j = 2:trainDataLength
                                 bundledTrainData{i, 1}(j, :) = bundledTrainData_2{i, 1}(:, :);
                        end
                        bundledTrainData{i, 1} = bundledTrainData{i, 1}';
                end

                for i = 1:testDataSize
                        for j = 2:testDataLength
                                 bundledTestData{i, 1}(j, :) = bundledTestData_2{i, 1}(:, :);
                        end
                        bundledTestData{i, 1} = bundledTestData{i, 1}';
                end

                bundledTrainData =  cellfun(@(x) permute(x,[3,2,1]), bundledTrainData,'uniformOutput',false);
                bundledTestData = cellfun(@(x) permute(x,[3,2,1]), bundledTestData,'uniformOutput',false);

                bundledTrainData =  cellfun(@(x) squeeze(x), bundledTrainData,'uniformOutput',false);
                bundledTestData = cellfun(@(x) squeeze(x), bundledTestData,'uniformOutput',false);

                condition = trainFormattedDataArray(1).condition;
                
                oneDimTrainLabel = bundledTrainLabel';
                oneDimTestLabel = bundledTestLabel';

                train = TrainTestDataTwo(bundledTrainData,bundledTrainLabel,trainDataMinimumAmount,condition,oneDimTrainLabel);
                test = TrainTestDataTwo(bundledTestData, bundledTestLabel,testDataMinimumAmount,condition,oneDimTestLabel);

                clear trainData trainLabel testData testLabel;
        end
    
        % --- TrainTestDataCreatorTwo クラス内に追加するメソッド ---

        function [trainCapWave, trainDiffWave, trainLabel, ...
                  testCapWave, testDiffWave, testLabel] = ...
                  createDualWaveInputs(obj, trainFormattedDataArray, testFormattedDataArray, preProcessorFunc)
            arguments
                obj TrainTestDataCreatorTwo
                trainFormattedDataArray (1,:) FormattedDataTwo
                testFormattedDataArray (1,:) FormattedDataTwo
                preProcessorFunc
            end
            
            conditionLength = length(trainFormattedDataArray(1).condition);
            trainDataLength = length(trainFormattedDataArray);
            testDataLength = length(testFormattedDataArray);
        
            % --- 1. データの抽出と条件ごとの結合 (CapWave, DiffWave) ---
            
            extraction_func_cap = @(data, j) data.capacitanceCell{j};
            [trainCapCombined, testCapCombined, trainLabelCombined, testLabelCombined] = ...
                obj.combineDataByCondition(trainFormattedDataArray, testFormattedDataArray, extraction_func_cap, conditionLength, trainDataLength, testDataLength);
            
            extraction_func_diff = @(data, j) data.differentialPressureCell{j};
            [trainDiffCombined, testDiffCombined, ~, ~] = ...
                obj.combineDataByCondition(trainFormattedDataArray, testFormattedDataArray, extraction_func_diff, conditionLength, trainDataLength, testDataLength);
        
            % --- 2. 最小サンプル数を計算 (CapWave を基準) ---
            trainMin = min(cellfun(@(x) size(x,1), trainCapCombined));
            testMin  = min(cellfun(@(x) size(x,1), testCapCombined));
        
            % --- 3. 全てのセル内のデータを最小サンプル数に切り捨てる ---
            for j = 1:conditionLength
                idxTrain = 1:trainMin;
                trainCapCombined{j} = trainCapCombined{j}(idxTrain, :);
                trainDiffCombined{j} = trainDiffCombined{j}(idxTrain, :);
                trainLabelCombined{j} = trainLabelCombined{j}(idxTrain, :);
        
                idxTest = 1:testMin;
                testCapCombined{j} = testCapCombined{j}(idxTest, :);
                testDiffCombined{j} = testDiffCombined{j}(idxTest, :);
                testLabelCombined{j} = testLabelCombined{j}(idxTest, :);
            end
        
            % --- 4. 前処理（標準化）を波形データにのみ適用 (データ漏洩対策済み) ---
            
            mu_cap_train = cell(1, conditionLength);
            sig_cap_train = cell(1, conditionLength);
            mu_diff_train = cell(1, conditionLength);
            sig_diff_train = cell(1, conditionLength);

            for j = 1:conditionLength
                % 4a. 訓練データの標準化（CapWave）: 統計量を計算し、保存し、適用
                [mu_j, sig_j] = calculate_stats_for_cell(trainCapCombined{j}); % ★ obj. を削除 ★
                mu_cap_train{j} = mu_j;
                sig_cap_train{j} = sig_j;
                trainCapCombined{j} = apply_standardization(trainCapCombined{j}, mu_j, sig_j); % ★ obj. を削除 ★

                % 4c. 訓練データの標準化（DiffWave）: 統計量を計算し、保存し、適用
                [mu_j, sig_j] = calculate_stats_for_cell(trainDiffCombined{j}); % ★ obj. を削除 ★
                mu_diff_train{j} = mu_j;
                sig_diff_train{j} = sig_j;
                trainDiffCombined{j} = apply_standardization(trainDiffCombined{j}, mu_j, sig_j); % ★ obj. を削除 ★
            end
            
            % 4b, 4d. テストデータの標準化: 訓練データの統計量のみを適用
            for j = 1:conditionLength
                % CapWave: 訓練データの mu/sig を使用
                testCapCombined{j} = apply_standardization(testCapCombined{j}, mu_cap_train{j}, sig_cap_train{j}); % ★ obj. を削除 ★
                
                % DiffWave: 訓練データの mu/sig を使用
                testDiffCombined{j} = apply_standardization(testDiffCombined{j}, mu_diff_train{j}, sig_diff_train{j}); % ★ obj. を削除 ★
            end
        

            % --- 5. 全ての条件のデータを最終結合 (巨大な行列へ) ---
            % trainCapCombined は 12個の要素を持つ Cell Array。
            % vertcat を使って、全ての条件のデータ行列を縦方向に結合し、巨大な行列にする。
            trainCapDataMatrix = vertcat(trainCapCombined{:});
            testCapDataMatrix = vertcat(testCapCombined{:});
            trainDiffDataMatrix = vertcat(trainDiffCombined{:});
            testDiffDataMatrix = vertcat(testDiffCombined{:});
            
            % ラベルは既に条件ごとに結合されたベクトル (12要素) を持っているので、単純に結合
            trainLabel = vertcat(trainLabelCombined{:});
            testLabel = vertcat(testLabelCombined{:});
            
            
      
            
            % --- 6. 最終整形 (LSTMが要求する 3次元配列形式に変換) ---
            
            % 1. 結合された巨大な行列を、各サンプルを行とする Cell 配列に変換
            % [N_total x 400] -> [N_total x {1 x 400}] の Cell Array
            trainCapWave = num2cell(trainCapDataMatrix, 2);
            testCapWave = num2cell(testCapDataMatrix, 2);
            trainDiffWave = num2cell(trainDiffDataMatrix, 2);
            testDiffWave = num2cell(testDiffDataMatrix, 2);

            % 2. Cell配列内の各要素（各シーケンス）を転置し、
            % 形状を [1 x 400] から [400 x 1] に強制変換する。
            trainCapWave = cellfun(@transpose, trainCapWave, 'UniformOutput', false);
            testCapWave = cellfun(@transpose, testCapWave, 'UniformOutput', false);
            trainDiffWave = cellfun(@transpose, trainDiffWave, 'UniformOutput', false);
            testDiffWave = cellfun(@transpose, testDiffWave, 'UniformOutput', false);
            
            % Label: Categorical に変換 (変更なし)
            trainLabel = categorical(trainLabel);
            testLabel = categorical(testLabel);
            
            
        end

        % for文を一回で回してしまいたいので, この返り値の多さには目をつむりたい
        function [trainData, trainLabel, trainDataMinimumAmount,testData, testLabel, testDataMinimumAmount,trainAccurateLiquidFlowRate, trainAccurateGasFlowRate,testAccurateLiquidFlowRate, testAccurateGasFlowRate] ...
                = createNormalDataCoreWithAccurateFlowRate(obj, trainFormattedDataArray, testFormattedDataArray)
            arguments
                obj TrainTestDataCreatorTwo
                trainFormattedDataArray (1,:) FormattedDataTwo
                testFormattedDataArray (1,:) FormattedDataTwo
            end
            conditionLength = length(trainFormattedDataArray(1).condition);
            trainData=cell(1,conditionLength);
            trainLabel=cell(1,conditionLength);
            trainAccurateLiquidFlowRate = cell(1,conditionLength);
            trainAccurateGasFlowRate = cell(1,conditionLength);

            testData=cell(1,conditionLength);
            testLabel=cell(1,conditionLength);
            testAccurateLiquidFlowRate = cell(1,conditionLength);
            testAccurateGasFlowRate =cell(1,conditionLength);

            %各流量条件ごとにセル配列の中身に連ねていく.====================
            % ✅ 修正済み: machineLearningCell からデータ抽出
            for i=1:conditionLength
                for j=1:length(trainFormattedDataArray)
                    trainData{i}=vertcat(trainData{i},trainFormattedDataArray(j).machineLearningCell{i});
                    trainLabel{i} = vertcat(trainLabel{i}, trainFormattedDataArray(j).labelCell{i});
                    trainAccurateLiquidFlowRate{i} =  vertcat(trainAccurateLiquidFlowRate{i}, trainFormattedDataArray(j).liquidFlowRateOfEachData{i});
                    trainAccurateGasFlowRate{i} =  vertcat(trainAccurateGasFlowRate{i}, trainFormattedDataArray(j).gasFlowRateOfEachData{i});
                end

                for j = 1: length(testFormattedDataArray)
                    testData{i} = vertcat(testData{i}, testFormattedDataArray(j).machineLearningCell{i});
                    testLabel{i} = vertcat(testLabel{i}, testFormattedDataArray(j).labelCell{i});
                    testAccurateLiquidFlowRate{i} =  vertcat(testAccurateLiquidFlowRate{i}, testFormattedDataArray(j).liquidFlowRateOfEachData{i});
                    testAccurateGasFlowRate{i} =  vertcat(testAccurateGasFlowRate{i}, testFormattedDataArray(j).gasFlowRateOfEachData{i});
                end
            end
            % ==========================================================================

            %すべての流量条件で「訓練」データ数を合わせる. ==========================
            trainDataMinimumAmount = numel(trainData{1}(:,1));

            %最小の訓練データ数を拾ってくる
            for i=1:conditionLength
                if numel(trainData{i}(:,1))<trainDataMinimumAmount
                    trainDataMinimumAmount=numel(trainData{i}(:,1));
                end
            end

            for i=1:conditionLength
                if numel(trainData{i}(:,1))>=trainDataMinimumAmount
                    % 最小のデータに合わせてランダムにデータを落とす.
                    % ランダムにデータを落としては駄目．確認する時に色々手間になる
                    idx=1:trainDataMinimumAmount; %randperm(numel(trainData{i}(:,1)),trainDataMinimumAmount);
                    trainData{i}=trainData{i}(idx,:,:);
                    trainLabel{i}=trainLabel{i}(idx,:,:);
                    trainAccurateLiquidFlowRate{i} = trainAccurateLiquidFlowRate{i} (idx,:,:);
                    trainAccurateGasFlowRate{i} = trainAccurateGasFlowRate{i}(idx,:,:);
                end
            end
            % =====================================================================

            %すべての流量条件でテストデータ数を合わせる. ============================
            testDataMinimumAmount = numel(testData{1}(:,1));
            for i=1:conditionLength
                if numel(testData{i}(:,1))<testDataMinimumAmount
                    testDataMinimumAmount=numel(testData{i}(:,1));
                end
            end

            for i=1:conditionLength
                if numel(testData{i}(:,1))>=testDataMinimumAmount
                    idx=1:testDataMinimumAmount;%randperm(numel(testData{i}(:,1)),testDataMinimumAmount);
                    testData{i}=testData{i}(idx,:,:);
                    testLabel{i}=testLabel{i}(idx,:,:);
                    testAccurateLiquidFlowRate{i} = testAccurateLiquidFlowRate{i}(idx,:,:);
                    testAccurateGasFlowRate{i} = testAccurateGasFlowRate{i}(idx,:,:);
                end
            end
        end
   
        function [trainData, trainLabel, trainDataMinimumAmount,testData, testLabel, testDataMinimumAmount] = createNormalDataCore(obj, trainFormattedDataArray, testFormattedDataArray)
            arguments
                obj TrainTestDataCreatorTwo
                trainFormattedDataArray (1,:) FormattedDataTwo
                testFormattedDataArray (1,:) FormattedDataTwo
            end
            conditionLength = length(trainFormattedDataArray(1).condition);
            trainData=cell(1,conditionLength);
            trainLabel=cell(1,conditionLength);
            testData=cell(1,conditionLength);
            testLabel=cell(1,conditionLength);

            %各流量条件ごとにセル配列の中身に連ねていく.
            % ✅ 修正済み: machineLearningCell からデータ抽出
            for i=1:conditionLength
                for j=1:length(trainFormattedDataArray)
                    trainData{i}=vertcat(trainData{i},trainFormattedDataArray(j).machineLearningCell{i});
                    trainLabel{i} = vertcat(trainLabel{i}, trainFormattedDataArray(j).labelCell{i});
                end

                for j = 1: length(testFormattedDataArray)
                    testData{i} = vertcat(testData{i}, testFormattedDataArray(j).machineLearningCell{i});
                    testLabel{i} = vertcat(testLabel{i}, testFormattedDataArray(j).labelCell{i});
                end
            end

            %すべての流量条件で訓練データ数を合わせる.
            trainDataMinimumAmount = numel(trainData{1}(:,1));

            %最小の訓練データ数を拾ってくる
            for i=1:conditionLength
                if numel(trainData{i}(:,1))<trainDataMinimumAmount
                    trainDataMinimumAmount=numel(trainData{i}(:,1));
                end
            end

            for i=1:conditionLength
                if numel(trainData{i}(:,1))>=trainDataMinimumAmount
                    % 最小のデータに合わせてランダムにデータを落とす.
                    % ランダムは駄目
                    idx=1:trainDataMinimumAmount;%randperm(numel(trainData{i}(:,1)),trainDataMinimumAmount);
                    trainData{i}=trainData{i}(idx,:,:);
                    trainLabel{i}=trainLabel{i}(idx,:,:);
                end
            end

            %すべての流量条件でテストデータ数を合わせる.
            testDataMinimumAmount = numel(testData{1}(:,1));
            for i=1:conditionLength
                if numel(testData{i}(:,1))<testDataMinimumAmount
                    testDataMinimumAmount=numel(testData{i}(:,1));
                end
            end

            for i=1:conditionLength
                if numel(testData{i}(:,1))>=testDataMinimumAmount
                    % 最小のデータに合わせてランダムにデータを落とす.
                    idx=1:testDataMinimumAmount;%randperm(numel(testData{i}(:,1)),testDataMinimumAmount);
                    testData{i}=testData{i}(idx,:,:);
                    testLabel{i}=testLabel{i}(idx,:,:);
                end
            end
        end

        function [trainCapWave, trainDiffWave, trainFeature, trainLabel, ...
                          testCapWave, testDiffWave, testFeature, testLabel] = ...
                          createMultimodalInputs(obj, trainFormattedDataArray, testFormattedDataArray, preProcessorFunc)

            arguments
                obj TrainTestDataCreatorTwo
                trainFormattedDataArray (1,:) FormattedDataTwo
                testFormattedDataArray (1,:) FormattedDataTwo
                preProcessorFunc
            end

            conditionLength = length(trainFormattedDataArray(1).condition);
            trainDataLength = length(trainFormattedDataArray);
            testDataLength = length(testFormattedDataArray);

            % --- 1. データの抽出と条件ごとの結合 (CapWave, DiffWave, Feature) ---

            % CapWave (静電容量波形) を抽出
            [trainCapCombined, testCapCombined, trainLabelCombined, testLabelCombined] = ...
                obj.combineDataByCondition(trainFormattedDataArray, testFormattedDataArray, @(data, j) data.capacitanceCell{j}, conditionLength, trainDataLength, testDataLength);

            % DiffWave (差圧波形) を抽出
            [trainDiffCombined, testDiffCombined, ~, ~] = ...
                obj.combineDataByCondition(trainFormattedDataArray, testFormattedDataArray, @(data, j) data.differentialPressureCell{j}, conditionLength, trainDataLength, testDataLength);

            % Feature (静的特徴量) を抽出（今回（2025）は時系列の特徴量は利用なし）
            extraction_func = @(data, j) horzcat(data.machineLearningCell{j}{4}, data.machineLearningCell{j}{6}, data.machineLearningCell{j}{8});
            [trainFeatureCombined, testFeatureCombined, ~, ~] = ...
            obj.combineDataByCondition(trainFormattedDataArray, testFormattedDataArray, extraction_func, conditionLength, trainDataLength, testDataLength);

            % --- 2. 最小サンプル数を計算 (CapWave を基準) ---

            trainMin = min(cellfun(@(x) size(x,1), trainCapCombined));
            testMin  = min(cellfun(@(x) size(x,1), testCapCombined));

            % --- 3. 全てのセル内のデータを最小サンプル数に切り捨てる ---

            for j = 1:conditionLength
                idxTrain = 1:trainMin;

                % Waveform (CapWave): trainMin でタイムステップを切り捨てる (行方向)
                trainCapCombined{j} = trainCapCombined{j}(idxTrain, :);
                trainDiffCombined{j} = trainDiffCombined{j}(idxTrain, :);
                
                % ★ 修正案 A: Feature (静的特徴量) の切り捨て処理を追加 ★
                trainFeatureCombined{j} = trainFeatureCombined{j}(idxTrain, :);
                
                % Label: CapWaveに合わせて切り捨てる (行方向)
                trainLabelCombined{j} = trainLabelCombined{j}(idxTrain, :);

                idxTest = 1:testMin;

                % Waveform (CapWave)
                testCapCombined{j} = testCapCombined{j}(idxTest, :);
                testDiffCombined{j} = testDiffCombined{j}(idxTest, :);
                
                % ★ 修正案 A: Feature (静的特徴量) の切り捨て処理を追加 ★
                testFeatureCombined{j} = testFeatureCombined{j}(idxTest, :);
                
                % Label
                testLabelCombined{j} = testLabelCombined{j}(idxTest, :);
            end

            % --- 4. 前処理（標準化）を波形データにのみ適用 ---

            % 4a. 訓練データの標準化（CapWave）
            for j = 1:conditionLength
                % calculate_stats_for_cell が 2D/空データ対応済み
                [mu_j, sig_j] = calculate_stats_for_cell(trainCapCombined{j});
                trainCapCombined{j} = apply_standardization(trainCapCombined{j}, mu_j, sig_j);
            end

            % 4b. テストデータの標準化（CapWave）
            for j = 1:conditionLength
                [mu_j, sig_j] = calculate_stats_for_cell(testCapCombined{j});
                testCapCombined{j} = apply_standardization(testCapCombined{j}, mu_j, sig_j);
            end

            % 4c. 訓練データの標準化（DiffWave）
            for j = 1:conditionLength
                [mu_j, sig_j] = calculate_stats_for_cell(trainDiffCombined{j});
                trainDiffCombined{j} = apply_standardization(trainDiffCombined{j}, mu_j, sig_j);
            end

            % 4d. テストデータの標準化（DiffWave）
            for j = 1:conditionLength
                [mu_j, sig_j] = calculate_stats_for_cell(testDiffCombined{j});
                testDiffCombined{j} = apply_standardization(testDiffCombined{j}, mu_j, sig_j);
            end

            % --- 5. 全ての条件のデータを最終結合 (Cell Array をそのまま使用) ---

            % Waveform: 最終出力形式（LSTM入力）は Cell Array なので、結合せずにそのまま Cell Array を使用
            % Feature/Label: vertcat で結合
            trainFeature = vertcat(trainFeatureCombined{:});
            testFeature  = vertcat(testFeatureCombined{:});
            trainLabel   = vertcat(trainLabelCombined{:});
            testLabel    = vertcat(testLabelCombined{:});

            % --- 6. 最終整形 ---

            % Waveform (Cap/Diff): ★ 修正 ★ Cell Array of [TimeSteps x Channels] を返すため、そのまま代入
            trainCapWave = trainCapCombined';
            testCapWave  = testCapCombined';
            trainDiffWave = trainDiffCombined';
            testDiffWave  = testDiffCombined';

            % Feature: 2D 行列に変換
            %trainFeature = cell2mat(trainFeature);
            %testFeature = cell2mat(testFeature);

            % Label: Categorical に変換
            trainLabel = categorical(trainLabel);
            testLabel  = categorical(testLabel);

        end % function createMultimodalInputs


    % --- データ抽出と結合ロジック (combineDataByCondition) ---
        function [trainCombined, testCombined, trainLabelCombined, testLabelCombined] = ...
        combineDataByCondition(obj, trainArray, testArray, dataExtractorFunc, conditionLength, trainDataLength, testDataLength)

        arguments
            obj TrainTestDataCreatorTwo
            trainArray (1,:) FormattedDataTwo
            testArray (1,:) FormattedDataTwo
            dataExtractorFunc function_handle % データを抽出するための関数ハンドル
            conditionLength (1,1) double
            trainDataLength (1,1) double
            testDataLength (1,1) double
        end

        trainCombined = cell(1, conditionLength);
        testCombined = cell(1, conditionLength);
        trainLabelCombined = cell(1, conditionLength);
        testLabelCombined = cell(1, conditionLength);

        % どのデータを抽出しているかを特定
        funcName = func2str(dataExtractorFunc);
        isWaveData = contains(funcName, 'capacitanceCell') || contains(funcName, 'differentialPressureCell');
        isFeatureData = contains(funcName, 'machineLearningCell');
        isCapWave = contains(funcName, 'capacitanceCell'); % ラベル結合は CapWave 抽出時のみ実行

        for j = 1:conditionLength % 条件 (流量)
            
            % 一時格納用
            trainDataCellTemp = {};
            testDataCellTemp = {};
            
            trainLabelTemp = [];
            testLabelTemp = [];
            trainFeatureTemp = [];
            testFeatureTemp = [];

            % 訓練データの結合
            for i = 1:trainDataLength
                currentData = dataExtractorFunc(trainArray(i), j);
                
                if isWaveData
                    % 波形データ (3D): セル配列として追加 (試行の独立性を保持)
                    if ~isempty(currentData)
                        trainDataCellTemp = [trainDataCellTemp, {currentData}];
                    end
                elseif isFeatureData
                    % 特徴量データ (2D): vertcat で縦に結合 
                    trainFeatureTemp = vertcat(trainFeatureTemp, currentData);
                end

                % ラベル結合: CapWave 抽出時のみ実行
                if isCapWave
                    trainLabelTemp = vertcat(trainLabelTemp, trainArray(i).labelCell{j});
                end
            end
            
            % テストデータの結合
            for i = 1:testDataLength
                currentData = dataExtractorFunc(testArray(i), j);
                
                if isWaveData
                    if ~isempty(currentData)
                        testDataCellTemp = [testDataCellTemp, {currentData}];
                    end
                elseif isFeatureData
                    testFeatureTemp = vertcat(testFeatureTemp, currentData);
                end

                % ラベル結合: CapWave 抽出時のみ実行
                if isCapWave
                    testLabelTemp = vertcat(testLabelTemp, testArray(i).labelCell{j});
                end
            end
            
            % 最終結合と格納
            if isWaveData
            % ★ 修正 ★ Trials=1 なので、cat(3) を削除し、セル配列の唯一の要素を直接取り出す
            % trainDataCellTemp の中には、唯一の 2D 行列 {data} が格納されているはず

            if ~isempty(trainDataCellTemp)
                trainCombined{j} = trainDataCellTemp{1};
            else
                trainCombined{j} = []; % データが空の場合は空のまま格納
            end

            if ~isempty(testDataCellTemp)
                testCombined{j} = testDataCellTemp{1};
            else
                testCombined{j} = [];
            end

            elseif isFeatureData
                % 特徴量データ: vertcat 済みの 2D 行列を格納
                trainCombined{j} = trainFeatureTemp;
                testCombined{j} = testFeatureTemp;
            end

            % ラベルを格納
            trainLabelCombined{j} = trainLabelTemp;
            testLabelCombined{j} = testLabelTemp;
        end
    end
    end
end
   
        % ----------------------------------------------------------------------
        % ⭐ ローカル/ユーティリティ関数（標準化処理の最終版）⭐
        % ----------------------------------------------------------------------
        function [mu_feat, sig_feat] = calculate_stats_for_cell(dataArray)
        % CALCULATE_STATS_FOR_CELL: 2次元または3次元の入力データから、特徴量ごとの平均と標準偏差を計算する。
        
            % 1. データが空の場合はここで処理を終了 (安全策)
            if isempty(dataArray)
                mu_feat = 0;
                sig_feat = 1e-6; % ゼロ除算回避のため
                warning('calculate_stats_for_cell: 処理するデータが空でした。統計量をゼロ/微小値に設定します。');
                return; 
            end
            
            % 2. ★ 修正 ★ 次元チェックとデータ展開のロジック
            
            if ~isnumeric(dataArray)
                 error('calculate_stats_for_cell: 入力データは数値行列である必要があります。');
            end
            
            currentDims = ndims(dataArray);
        
            if currentDims == 2
                % 入力が 2次元 [TimeSteps x N_features] の場合 (Trials=1 の場合)
                deployedData = dataArray;
            elseif currentDims >= 3
                % 入力が 3次元以上 [TimeSteps x N_features x N_sequence] の場合 (Trials > 1 の場合)
                % 全サンプル・全シーケンスのデータが特徴量ごとに縦に結合されるように展開
                deployedData = reshape(permute(dataArray, [2 1 3]), size(dataArray, 2), [])';
            else
                % データが1次元など、想定外の場合
                error('calculate_stats_for_cell: 入力データは2次元以上の数値行列である必要があります。');
            end
        
            % 3. 統計量計算 (特徴量ごと, 第2次元, 列方向)
            mu_feat = mean(deployedData, 1, 'omitnan');
            sig_feat = std(deployedData, 0, 1, 'omitnan');
            
            % 4. 標準偏差がゼロの特徴量への対策
            sig_feat(sig_feat == 0) = 1e-6; 
        end
        
        function processedData = apply_standardization(dataArray, mu, sig)
        % APPLY_STANDARDARDIZATION: 計算された統計量を使ってデータを変換する
        arguments
            dataArray (:, :, :) double % [N_samples x N_feat x N_sequence]
            mu (1, :) double           % [1 x N_feat]
            sig (1, :) double          % [1 x N_feat]
        end
            % 変換処理: (dataArray - mu) ./ sig
            % MATLABは自動的にmuとsigをデータ配列の第1次元と第3次元に拡張（ブロードキャスト）し、
            % 各サンプルの全タイムステップに正しく適用します。
            processedData = (dataArray - mu) ./ sig;
        end