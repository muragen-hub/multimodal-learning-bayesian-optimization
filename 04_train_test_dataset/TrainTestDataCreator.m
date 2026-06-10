classdef TrainTestDataCreator
    %CREATETRAINTESTDATA このクラスの概要をここに記述
    %   詳細説明をここに記述

    methods(Access = public)
        function obj = TrainTestDataCreator()
        end

        function [train, test] = createNormalData(obj, trainFormattedDataArray, testFormattedDataArray)
            %trainFormattedData, testFormattedData共に訓練, テストデータのしたいデータの配列.
            arguments
                obj TrainTestDataCreator
                trainFormattedDataArray (1,:) FormattedData
                testFormattedDataArray (1,:) FormattedData
            end
            [trainData, trainLabel, trainDataMinimumAmount,testData, testLabel, testDataMinimumAmount] = obj.createNormalDataCore(trainFormattedDataArray,testFormattedDataArray);

            % formatは訓練側, テスト側で全て同じになるようにされていると仮定する.
            condition = trainFormattedDataArray(1).condition;
            label = trainFormattedDataArray(1).label;
            conditionLength = length(condition);
            dataWidth = trainFormattedDataArray(1).option.dataWidth;
            inputSize = size(trainData{1},3);

            % 1 * 流量条件個数のcell配列からdataWidthのデータの最小の個数*流量条件個数 * dataWidthに変更
            bundledTrainData=zeros(trainDataMinimumAmount*conditionLength, dataWidth,inputSize);
            bundledTrainLabel=strings(trainDataMinimumAmount*conditionLength,1);
            bundledTestData=zeros(testDataMinimumAmount*conditionLength, dataWidth,inputSize);
            bundledTestLabel=strings(testDataMinimumAmount*conditionLength,1);

            for i=1:conditionLength
                bundledTrainData((i-1)*trainDataMinimumAmount+1: i*trainDataMinimumAmount, :,:) = trainData{i};
                bundledTrainLabel((i-1)*trainDataMinimumAmount+1: i*trainDataMinimumAmount, :,:) = trainLabel{i};

                bundledTestData((i-1)*testDataMinimumAmount+1: i*testDataMinimumAmount, :,:) = testData{i};
                bundledTestLabel((i-1)*testDataMinimumAmount+1: i*testDataMinimumAmount, :,:) = testLabel{i};
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
                trainLabels = [trainLabels trainFormattedDataArray(ii).label]; %#ok たかだか数回だからループの度に更新しても別に.  
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
                obj TrainTestDataCreator
                trainFormattedDataArray (1,:) FormattedData
                testFormattedDataArray (1,:) FormattedData
            end
             [trainData, trainLabel, trainDataMinimumAmount,testData, testLabel, testDataMinimumAmount,trainAccurateLiquidFlowRate, trainAccurateGasFlowRate,testAccurateLiquidFlowRate, testAccurateGasFlowRate]...
                = obj.createNormalDataCoreWithAccurateFlowRate(trainFormattedDataArray,testFormattedDataArray);
             % formatは訓練側, テスト側で全て同じになるようにされていると仮定する.
            condition = trainFormattedDataArray(1).condition;
            label = trainFormattedDataArray(1).label;
            conditionLength = length(condition);
            dataWidth = trainFormattedDataArray(1).option.dataWidth;
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
                bundledTrainValueLabel((idx-1)*trainDataMinimumAmount+1:idx*trainDataMinimumAmount,:,:) = cat(2,trainData{idx}(1:end-1,2:end,:),trainData{idx}(2:end,1,:));
                
                bundledTrainLabel((idx-1)*trainDataMinimumAmount +1: idx*trainDataMinimumAmount, :) = trainLabel{idx}(1:end-1);
                bundledTrainAccurateLiquidFlowRate((idx-1)*trainDataMinimumAmount +1: idx*trainDataMinimumAmount, :) = trainAccurateLiquidFlowRate{idx}(1:end-1,1);
                bundledTrainAccurateGasFlowRate((idx-1)*trainDataMinimumAmount +1: idx*trainDataMinimumAmount, :) = trainAccurateGasFlowRate{idx}(1:end-1,1);

                bundledTestData((idx-1)*testDataMinimumAmount+1:idx*testDataMinimumAmount,:,:) = testData{idx}(1:end-1,:,:);
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
                obj TrainTestDataCreator
                trainFormattedDataArray (1,:) FormattedData
                testFormattedDataArray (1,:) FormattedData
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
            dataWidth = trainFormattedDataArray(1).option.dataWidth;
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

        % 複数の特徴量を入力する場合
        function [train, test] = createMultiVectorData(obj, trainFormattedDataArray, testFormattedDataArray)
            arguments
                obj TrainTestDataCreator
                trainFormattedDataArray (1,:) FormattedData
                testFormattedDataArray (1,:) FormattedData
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

            train = TrainTestData(bundledTrainData,bundledTrainLabel,trainDataMinimumAmount,condition,label);
            test = TrainTestData(bundledTestData, bundledTestLabel,testDataMinimumAmount,condition,label);

            clear trainData trainLabel testData testLabel;
        end


        function [train, test] = createAndPreProcessMultimodalData(obj, trainFormattedDataArray, testFormattedDataArray, preProcessorFunc)
                arguments
                    obj TrainTestDataCreator
                    trainFormattedDataArray (1,:) FormattedData
                    testFormattedDataArray (1,:) FormattedData
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

                for i_1=1:conditionLength
                        for j_1=1:trainDataLength
                                trainData{j_1, i_1}=trainFormattedDataArray(j_1).capacitanceCell{i_1};
                                trainLabel{j_1, i_1} = trainFormattedDataArray(j_1).labelCell{i_1};
                        end

                        for k_1 = 1: length(testFormattedDataArray)
                                testData{k_1, i_1} = testFormattedDataArray(k_1).capacitanceCell{i_1};
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
                
                dataWidth = trainFormattedDataArray(1).option.dataWidth;
                inputSize = size(trainData{1},3);
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

                train = TrainTestData(bundledTrainData,bundledTrainLabel,trainDataMinimumAmount,condition,oneDimTrainLabel);
                test = TrainTestData(bundledTestData, bundledTestLabel,testDataMinimumAmount,condition,oneDimTestLabel);

                clear trainData trainLabel testData testLabel;
        end

        % TrainTestDataCreator クラスの methods(Access = public) 内に追加

        function [train, test] = createAndPreProcessMultimodalWaveData(obj, trainFormattedDataArray, testFormattedDataArray, preProcessorFunc)
                % CREATEANDPREPROCESSMULTIMODALWAVEDATA: 複数のFormattedDataWave配列を結合し、前処理を行う
                arguments
                    obj TrainTestDataCreator
                    % ★ 入力型を FormattedDataWave に変更
                    trainFormattedDataArray (1,:) FormattedDataWave 
                    testFormattedDataArray (1,:) FormattedDataWave
                    preProcessorFunc
                end
                
                % メタデータ取得
                condition = trainFormattedDataArray(1).condition;
                label = trainFormattedDataArray(1).label;
                conditionLength = length(trainFormattedDataArray(1).condition);
                
                % trainDataLength/testDataLength は、VFとPrなどのデータタイプ数 (例: 2)
                trainDataLength = length(trainFormattedDataArray); 
                testDataLength = length(testFormattedDataArray);

                % セル配列を初期化: [データタイプ x 流量条件] の構造
                trainData=cell(trainDataLength, conditionLength); 
                trainLabel=cell(trainDataLength, conditionLength);
                testData=cell(testDataLength, conditionLength);
                testLabel=cell(testDataLength, conditionLength);

                % 1. 各データタイプ (VF, Pr) かつ 各流量条件ごとにデータを抽出 ========================
                for i_cond = 1:conditionLength % 流量条件 (Condition) のインデックス
                    for j_train = 1:trainDataLength % データタイプ (VF, Prなど) のインデックス
                            % ★ FormattedDataWaveのプロパティ名 waveDataCell を使用
                            trainData{j_train, i_cond} = trainFormattedDataArray(j_train).waveDataCell{i_cond};
                            trainLabel{j_train, i_cond} = trainFormattedDataArray(j_train).labelCell{i_cond};
                    end
                    for k_test = 1: testDataLength
                            testData{k_test, i_cond} = testFormattedDataArray(k_test).waveDataCell{i_cond};
                            testLabel{k_test, i_cond} = testFormattedDataArray(k_test).labelCell{i_cond};
                    end
                end
                % ==================================================================================

                % 2. 最小データ数の決定とデータの切り捨て (ロジックは流用) ==========================
                
                % 訓練データ最小値
                trainDataMinimumAmount = numel(trainData{1, 1}(:,1));
                for i_2 = 1:trainDataLength
                    for j_2 = 1:conditionLength
                        if numel(trainData{i_2, j_2}(:,1)) < trainDataMinimumAmount
                            trainDataMinimumAmount = numel(trainData{i_2, j_2}(:,1));
                        end
                    end
                end
                % データの切り捨て
                 for i_3 = 1:conditionLength
                    for j_3 = 1:trainDataLength
                         if numel(trainData{j_3 , i_3}(:,1)) >= trainDataMinimumAmount
                                idx = 1:trainDataMinimumAmount;
                                trainData{j_3, i_3} = trainData{j_3, i_3}(idx, :, :);
                                trainLabel{j_3, i_3} = trainLabel{j_3, i_3}(idx, :, :);
                         end
                    end
                end

                % テストデータ最小値
                testDataMinimumAmount = numel(testData{1, 1}(:,1));
                for i_4=1:testDataLength
                    for j_4 = 1:conditionLength
                        if numel(testData{i_4, j_4}(:,1))<testDataMinimumAmount
                            testDataMinimumAmount=numel(testData{i_4, j_4}(:,1));
                        end
                    end
                end
                % データの切り捨て
                for i_5 = 1:conditionLength
                    for j_5 = 1:testDataLength
                        if numel(testData{j_5 , i_5}(:,1)) >= testDataMinimumAmount
                                idx = 1:testDataMinimumAmount;
                                testData{j_5, i_5} = testData{j_5, i_5}(idx, :, :);
                                testLabel{j_5, i_5} = testLabel{j_5, i_5}(idx, :, :);
                        end
                    end
                end
                
                % ==================================================================================
                
                % 3. データの結合: Multimodal (VFとPr) をチャンネル次元で連結 ============================
                
                dataWidth = trainFormattedDataArray(1).option.dataWidth;

                
                % ★ 修正: 結合後のデータ幅を計算する
                %combinedDataWidth = 0;
                %for j = 1:trainDataLength
                    % trainData{j, 1} は [N x W x C] 形式
                 %   combinedDataWidth = combinedDataWidth + size(trainData{j, 1}, 2); 
                %end
                %dataWidth = combinedDataWidth; % <-- ここで dataWidth が 800 になることを期待

                % 全チャンネル数の計算 (データタイプ数がそのままチャンネル数 C_j=1 と仮定)
                totalInputSize = 0;
                for j = 1:trainDataLength
                    totalInputSize = totalInputSize + size(trainData{j, 1}, 3); 
                end
                
                trainDataSize = conditionLength * trainDataMinimumAmount;
                testDataSize = conditionLength * testDataMinimumAmount;
                
                % 最終的な結合済み配列: [N_Total x W x C_Total]
                bundledTrainData = zeros(trainDataSize, dataWidth, totalInputSize);
                bundledTestData  = zeros(testDataSize, dataWidth, totalInputSize);
                
                bundledTrainLabel = strings(trainDataSize, 1);
                bundledTestLabel  = strings(testDataSize, 1);

                for i = 1:conditionLength
                    startIdx_train = (i-1)*trainDataMinimumAmount + 1;
                    endIdx_train = i*trainDataMinimumAmount;
                    startIdx_test = (i-1)*testDataMinimumAmount + 1;
                    endIdx_test = i*testDataMinimumAmount;
                    
                    % 結合するデータセットのリストを作成
                    trainDataList = cell(1, trainDataLength);
                    testDataList = cell(1, testDataLength);
                    
                    for j = 1:trainDataLength
                        trainDataList{j} = trainData{j, i};
                        testDataList{j} = testData{j, i};
                    end
                    
                    % チャンネル次元 (3次元目) で連結
                    bundledTrainData(startIdx_train:endIdx_train, :, :) = cat(3, trainDataList{:});
                    bundledTestData(startIdx_test:endIdx_test, :, :) = cat(3, testDataList{:});
                    
                    % ラベルはすべてのデータタイプで共通なので、一つ目のデータから取得
                    bundledTrainLabel(startIdx_train:endIdx_train, :) = trainLabel{1, i}; 
                    bundledTestLabel(startIdx_test:endIdx_test, :) = testLabel{1, i};
                end
                
                bundledTrainLabel = categorical(bundledTrainLabel);
                bundledTestLabel = categorical(bundledTestLabel);
                
                % TrainTestDataCreator/createAndPreProcessMultimodalWaveData の最終部分

% ... (bundledTrainData, bundledTestData の num2cell 化はそのまま) ...
                
% 4. 前処理と最終整形 ===================================================================

% 3D配列をセル配列に変換: {N_Total x [W x C_Total]}
bundledTrainData = num2cell(bundledTrainData, [2 3]);
bundledTestData = num2cell(bundledTestData, [2 3]);

% ★ 修正 1: 結合後の幅を保存
combinedDataWidth = dataWidth;

% ★ 修正 2: preProcessorFunc を関数ハンドルに確実に変換する
%           既にハンドルであればそのまま、文字列であれば str2func を使用
if ischar(preProcessorFunc) || isstring(preProcessorFunc)
    funcToCall = str2func(preProcessorFunc);
else
    % 文字列でもハンドルでもない場合は、渡されたものをそのまま使用
    % (これが無効な型の場合、次の呼び出しでエラーとなるが、ここではそのまま進む)
    funcToCall = preProcessorFunc;
end

% ★ 最終修正: deal を使用して、関数呼び出しの結果を2つの変数に強制的に代入する。
%             これにより、出力数の不一致エラーを回避します。
[bundledTrainData, bundledTestData] = deal( funcToCall(bundledTrainData, bundledTestData, combinedDataWidth) );


% [N x W x C] のセル内のデータを [C x W x 1] へ permute
bundledTrainData =  cellfun(@(x) permute(x,[3,2,1]), bundledTrainData,'uniformOutput',false);
bundledTestData = cellfun(@(x) permute(x,[3,2,1]), bundledTestData,'uniformOutput',false);
                
% [C x W x 1] -> [C x W] へ squeeze (次元の削除)
bundledTrainData =  cellfun(@(x) squeeze(x), bundledTrainData,'uniformOutput',false);
bundledTestData = cellfun(@(x) squeeze(x), bundledTestData,'uniformOutput',false);
                
% 最終出力
oneDimTrainLabel = bundledTrainLabel'; % 行ベクトル化
oneDimTestLabel = bundledTestLabel';   % 行ベクトル化
                
train = TrainTestData(bundledTrainData, bundledTrainLabel, trainDataMinimumAmount, condition, oneDimTrainLabel);
test = TrainTestData(bundledTestData, bundledTestLabel, testDataMinimumAmount, condition, oneDimTestLabel);
                
clear trainData trainLabel testData testLabel;
        end
    end

    methods(Access = private)

        % for文を一回で回してしまいたいので, この返り値の多さには目をつむりたい
        function [trainData, trainLabel, trainDataMinimumAmount,testData, testLabel, testDataMinimumAmount,trainAccurateLiquidFlowRate, trainAccurateGasFlowRate,testAccurateLiquidFlowRate, testAccurateGasFlowRate] ...
                = createNormalDataCoreWithAccurateFlowRate(obj, trainFormattedDataArray, testFormattedDataArray)
            arguments
                obj TrainTestDataCreator
                trainFormattedDataArray (1,:) FormattedData
                testFormattedDataArray (1,:) FormattedData
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

            for i=1:conditionLength
                for j=1:length(trainFormattedDataArray)
                    trainData{i}=vertcat(trainData{i},trainFormattedDataArray(j).capacitanceCell{i});
                    trainLabel{i} = vertcat(trainLabel{i}, trainFormattedDataArray(j).labelCell{i});
                    trainAccurateLiquidFlowRate{i} =  vertcat(trainAccurateLiquidFlowRate{i}, trainFormattedDataArray(j).liquidFlowRateOfEachData{i});
                    trainAccurateGasFlowRate{i} =  vertcat(trainAccurateGasFlowRate{i}, trainFormattedDataArray(j).gasFlowRateOfEachData{i});
                end

                for j = 1: length(testFormattedDataArray)
                    testData{i} = vertcat(testData{i}, testFormattedDataArray(j).capacitanceCell{i});
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
            %======================================================================
        end

        function [trainData, trainLabel, trainDataMinimumAmount,testData, testLabel, testDataMinimumAmount] = createNormalDataCore(obj, trainFormattedDataArray, testFormattedDataArray)
            arguments
                obj TrainTestDataCreator
                trainFormattedDataArray (1,:) FormattedData
                testFormattedDataArray (1,:) FormattedData
            end
            conditionLength = length(trainFormattedDataArray(1).condition);
            trainData=cell(1,conditionLength);
            trainLabel=cell(1,conditionLength);
            testData=cell(1,conditionLength);
            testLabel=cell(1,conditionLength);

            %各流量条件ごとにセル配列の中身に連ねていく.

            for i=1:conditionLength
                for j=1:length(trainFormattedDataArray)
                    trainData{i}=vertcat(trainData{i},trainFormattedDataArray(j).capacitanceCell{i});
                    trainLabel{i} = vertcat(trainLabel{i}, trainFormattedDataArray(j).labelCell{i});
                end

                for j = 1: length(testFormattedDataArray)
                    testData{i} = vertcat(testData{i}, testFormattedDataArray(j).capacitanceCell{i});
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
    end
end
