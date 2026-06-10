classdef LayerSettingCreatorWave
    %LAYERSETTINGCREATORWAVE 
    %  波形用のレイヤー設定クラス（LayerSettingCreator と互換）

    properties (SetAccess = immutable)
        trainData TrainTestDataWave
        testData  TrainTestDataWave
    end

    methods
        function obj = LayerSettingCreatorWave(trainData, testData)
            arguments
                trainData TrainTestDataWave
                testData  TrainTestDataWave
            end
            obj.trainData = trainData;
            obj.testData = testData;
        end

        % ============================================================
        % ① 通常の LSTM → FC → Softmax → Classification
        % ============================================================
        function layerSetting = createSingleLSTMLayer(obj, inputSize, hiddenUnitAmount)
            arguments
                obj LayerSettingCreatorWave
                inputSize {mustBeNumeric}
                hiddenUnitAmount {mustBeNumeric}
            end

            % クラス数
            classAmount = length(unique(obj.trainData.labelStrings));

            layerSetting =  [ ...
                sequenceInputLayer(inputSize,'Name','Seq')
                bilstmLayer(hiddenUnitAmount,'OutputMode','last','Name','biLSTM')
                fullyConnectedLayer(classAmount,'Name','fc')
                softmaxLayer('Name','softmax')
                classificationLayer('Name','classification')];
        end

        % ============================================================
        % ② カスタム損失関数用（classification layer なし）
        % ============================================================
        function layerSetting = createSingleLSTMLayerForCustomLossFunc(obj,inputSize,hiddenUnitAmount)
            arguments
                obj LayerSettingCreatorWave
                inputSize {mustBeNumeric}
                hiddenUnitAmount {mustBeNumeric}
            end

            classAmount = length(unique(obj.trainData.labelStrings));

            layerSetting =  [ ...
                sequenceInputLayer(inputSize,'Name','Seq')
                bilstmLayer(hiddenUnitAmount,'OutputMode','last','Name','biLSTM')
                fullyConnectedLayer(classAmount,'Name','fc')
                softmaxLayer('Name','softmax')];
        end

        % ============================================================
        % ③ 複数入力向け（classification layer あり）
        % ============================================================
        function layerSetting = createSingleSeqToProbLSTMLayer(obj,inputSize,hiddenUnitAmount)
            arguments
                obj LayerSettingCreatorWave
                inputSize {mustBeNumeric}
                hiddenUnitAmount {mustBeNumeric}
            end

            classAmount = length(unique(obj.trainData.labelStrings));

            layerSetting =  [ ...
                sequenceInputLayer(inputSize,'Name','Seq')
                bilstmLayer(hiddenUnitAmount,'OutputMode','last','Name','biLSTM')
                fullyConnectedLayer(classAmount,'Name','fc')
                softmaxLayer('Name','softmax')
                classificationLayer];
        end
    end
end
