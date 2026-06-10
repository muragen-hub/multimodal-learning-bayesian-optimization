classdef TrainTestDataCreatorWave < TrainTestDataCreator
    % TRAINTESTDATACREATORWAVE: Multimodal Wave Data (VF/Prなど) を作成し、前処理を行うクラス
    % TrainTestDataCreator クラスを継承し、波形データに特化した処理を提供します。
    
    methods (Access = public)
        
        function [train, test] = createAndPreProcessMultimodalWaveData(obj, trainFormattedDataArray, testFormattedDataArray, preProcessorFunc)
            % CREATEANDPREPROCESSMULTIMODALWAVEDATA: 複数のFormattedDataWave配列を結合し、前処理を行う
            arguments
                obj TrainTestDataCreatorWave
                trainFormattedDataArray (1,:) FormattedDataWave 
                testFormattedDataArray (1,:) FormattedDataWave
                preProcessorFunc % 'cellInputStandardizeWave_OneOut' のような関数名（単一出力関数を想定）
            end
            
            % 1. データの抽出と最小データ数の決定 ==================================================
            
            condition = trainFormattedDataArray(1).condition;
            label = trainFormattedDataArray(1).label;
            conditionLength = length(trainFormattedDataArray(1).condition);
            trainDataLength = length(trainFormattedDataArray); % データタイプ数 (例: VF/Prで 2)
            testDataLength = length(testFormattedDataArray);
            
            % セル配列を初期化: [データタイプ x 流量条件] の構造
            trainData=cell(trainDataLength, conditionLength); 
            trainLabel=cell(trainDataLength, conditionLength);
            testData=cell(testDataLength, conditionLength);
            testLabel=cell(testDataLength, conditionLength);

            % データ抽出 (waveDataCellを使用)
            for i_cond = 1:conditionLength % 流量条件
                for j_train = 1:trainDataLength % データタイプ
                    trainData{j_train, i_cond} = trainFormattedDataArray(j_train).waveDataCell{i_cond};
                    trainLabel{j_train, i_cond} = trainFormattedDataArray(j_train).labelCell{i_cond};
                end
                for k_test = 1: testDataLength
                    testData{k_test, i_cond} = testFormattedDataArray(k_test).waveDataCell{i_cond};
                    testLabel{k_test, i_cond} = testFormattedDataArray(k_test).labelCell{i_cond};
                end
            end
            
            % 最小データ数の決定とデータの切り捨て
            [trainDataMinimumAmount, testDataMinimumAmount, trainData, trainLabel, testData, testLabel] = ...
                obj.cutDataToMinimumLength(trainData, trainLabel, testData, testLabel, trainDataLength, testDataLength, conditionLength);
            
            % 2. データの結合: チャンネル次元 (3次元目) で連結 ===================================
            
            % 修正: データ幅 (W) は一つ目のデータセットのWと同じ (例: 400)
            dataWidth = size(trainData{1, 1}, 2); 
            
            % 全チャンネル数の計算 (VF/Prなどすべてのチャンネルの合計)
            totalInputSize = 0;
            for j = 1:trainDataLength
                totalInputSize = totalInputSize + size(trainData{j, 1}, 3); 
            end
            
            trainDataSize = conditionLength * trainDataMinimumAmount;
            testDataSize = conditionLength * testDataMinimumAmount;
            
            % 最終的な結合済み配列: [N_Total x W(400) x C_Total(2)]
            bundledTrainData = zeros(trainDataSize, dataWidth, totalInputSize);
            bundledTestData  = zeros(testDataSize, dataWidth, totalInputSize);
            
            bundledTrainLabel = strings(trainDataSize, 1);
            bundledTestLabel  = strings(testDataSize, 1);
            
            for i = 1:conditionLength
                startIdx_train = (i-1)*trainDataMinimumAmount + 1;
                endIdx_train = i*trainDataMinimumAmount;
                startIdx_test = (i-1)*testDataMinimumAmount + 1;
                endIdx_test = i*testDataMinimumAmount;
                
                trainDataList = cell(1, trainDataLength);
                testDataList = cell(1, testDataLength);
                
                for j = 1:trainDataLength
                    trainDataList{j} = trainData{j, i};
                    testDataList{j} = testData{j, i};
                end
                
                % ★ 修正: チャンネル次元 (3次元目) で連結 (VFとPrを特徴量として結合)
                bundledTrainData(startIdx_train:endIdx_train, :, :) = cat(3, trainDataList{:});
                bundledTestData(startIdx_test:endIdx_test, :, :) = cat(3, testDataList{:});
                
                bundledTrainLabel(startIdx_train:endIdx_train, :) = trainLabel{1, i}; 
                bundledTestLabel(startIdx_test:endIdx_test, :) = testLabel{1, i};
            end
            
            bundledTrainLabel = categorical(bundledTrainLabel);
            bundledTestLabel = categorical(bundledTestLabel);

            % 3. 前処理 (Single Output 関数による標準化) =======================================
            
            % 3D配列をセル配列に変換: {N_Total x [W x C_Total]}
            bundledTrainData = num2cell(bundledTrainData, [2 3]);
            bundledTestData = num2cell(bundledTestData, [2 3]);
            
            % ★ エラー回避: 結合後の幅 (W=400) を渡し、単一出力関数を直接呼び出す
            combinedDataWidth = dataWidth; 
            
            % 関数ハンドルの取得と変換
            if ischar(preProcessorFunc) || isstring(preProcessorFunc)
                funcToCall = str2func(preProcessorFunc);
            else
                funcToCall = preProcessorFunc;
            end

            % ★ 修正: 訓練データとテストデータを個別に処理 (単一出力関数を想定)
            bundledTrainData = funcToCall(bundledTrainData, combinedDataWidth);
            bundledTestData = funcToCall(bundledTestData, combinedDataWidth); 

            % 4. 最終的なLSTM/CNN入力形式への整形 ===============================================
            
            % [N x W x C] のセル内のデータを [C x W x 1] へ permute
            % bundledData: {N x [W x C]} -> cellfun(@(x) permute(x,[3,2,1])) -> {N x [C x W x 1]}
            bundledTrainData =  cellfun(@(x) permute(x,[3,2,1]), bundledTrainData,'uniformOutput',false);
            bundledTestData = cellfun(@(x) permute(x,[3,2,1]), bundledTestData,'uniformOutput',false);
            
            % [C x W x 1] -> [C x W] へ squeeze (次元の削除)
            % cellfun(@(x) squeeze(x)) -> {N x [C x W]}
            bundledTrainData =  cellfun(@(x) squeeze(x), bundledTrainData,'uniformOutput',false);
            bundledTestData = cellfun(@(x) squeeze(x), bundledTestData,'uniformOutput',false);
            
            % 5. TrainTestDataWave オブジェクトの作成 ==========================================
            
            condition = trainFormattedDataArray(1).condition;
            oneDimTrainLabel = bundledTrainLabel';
            oneDimTestLabel = bundledTestLabel';
            
            % TrainTestDataWave オブジェクトを作成
            train = TrainTestDataWave(bundledTrainData, bundledTrainLabel, trainDataMinimumAmount, condition, oneDimTrainLabel);
            test = TrainTestDataWave(bundledTestData, bundledTestLabel, testDataMinimumAmount, condition, oneDimTestLabel);
            
            clear trainData trainLabel testData testLabel;
        end
    end
    
    methods(Access = private)
        % データの最小長合わせと切り捨てロジックを独立したメソッドとして定義 (再利用性向上)
        function [trainDataMinimumAmount, testDataMinimumAmount, trainData, trainLabel, testData, testLabel] = ...
                 cutDataToMinimumLength(obj, trainData, trainLabel, testData, testLabel, trainDataLength, testDataLength, conditionLength)
            
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
                            trainLabel{j_3, i_3} = trainLabel{j_3, i_3}(idx);
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
                            testLabel{j_5, i_5} = testLabel{j_5, i_5}(idx);
                    end
                end
            end
        end
    end
end