classdef LayerSettingCreatorOneWave
    % LAYERSETTINGCREATORONEWAVE 
    %   単一波形データ用のレイヤー設定クラス。
    %   カスタム訓練ループ(dlfeval)での利用を想定し、最終層はSoftmaxまでとする。

    properties (SetAccess = immutable)
        trainData TrainTestDataWave
        testData  TrainTestDataWave
    end

    methods
        function obj = LayerSettingCreatorOneWave(trainData, testData)
            arguments
                trainData TrainTestDataWave
                testData  TrainTestDataWave
            end
            obj.trainData = trainData;
            obj.testData = testData;
        end

        % ============================================================
        % ① 訓練ループ (dlfeval) 用のレイヤー設定
        % ============================================================
        function layerSetting = createLSTMLayerForTrainLoop(obj, inputSize, hiddenUnitAmount)
            arguments
                obj LayerSettingCreatorOneWave
                inputSize {mustBeNumeric} % ここには 1 を設定する想定
                hiddenUnitAmount {mustBeNumeric}
            end

            classAmount = length(unique(obj.trainData.labelStrings));

            layerSetting = [ ...
            sequenceInputLayer(inputSize, 'Name', 'Seq')
            bilstmLayer(hiddenUnitAmount,'OutputMode','last','Name','biLSTM')
            
            % ★ 修正: squeezeLayer を追加し、サイズが 1 の Time 次元を確実に削除する ★
            %squeezeLayer('Name', 'squeeze_time_dim') % [C x 1 x B] -> [C x B] に強制変換
            
            dropoutLayer(0, 'Name', 'drop')
            
            fullyConnectedLayer(classAmount,'Name','fc')
            softmaxLayer('Name','softmax')];
        end

        % ============================================================
        % ② trainnetwork関数用（参考として残す）
        % ============================================================
        function layerSetting = createLSTMLayerForStandardTrain(obj, inputSize, hiddenUnitAmount)
            arguments
                obj LayerSettingCreatorOneWave
                inputSize {mustBeNumeric}
                hiddenUnitAmount {mustBeNumeric}
            end

            classAmount = length(unique(obj.trainData.labelStrings));

            layerSetting =  [ ...
                % 無効な引数 'SequenceDimension', 2 を削除
                sequenceInputLayer(inputSize, 'Name', 'Seq')
                bilstmLayer(hiddenUnitAmount,'OutputMode','last','Name','biLSTM')
                dropoutLayer(0, 'Name', 'drop')
                fullyConnectedLayer(classAmount,'Name','fc')
                softmaxLayer('Name','softmax')
                classificationLayer('Name','classification')];
        end
    end
end