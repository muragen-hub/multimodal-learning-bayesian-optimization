classdef LayerSettingCreator
    %LAYERCREATOR レイヤーの作製はここで行う. 
    %   詳細説明をここに記述

    properties(SetAccess = immutable)
        trainData TrainTestData
        testData TrainTestData
    end

    methods
        function obj = LayerSettingCreator(trainData,testData)
            obj.trainData = trainData;
            obj.testData = testData;
        end
        %通常. 
        function layerSetting = createSingleLSTMLayer(obj,inputSize, hiddenUnitAmount)
            arguments
                obj LayerSettingCreator
                inputSize {mustBeNumeric}
                hiddenUnitAmount {mustBeNumeric}
            end
            classAmount = length(unique(obj.trainData.labelStrings));
            layerSetting =  [ sequenceInputLayer(inputSize,'Name', 'Seq')
                %   bilstmLayer(hiddenUnitAmount,'OutputMode','sequence')
                %     bilstmLayer(hiddenUnitAmount,'OutputMode','sequence')
                %     bilstmLayer(hiddenUnitAmount,'OutputMode','sequence')
                bilstmLayer(hiddenUnitAmount,'OutputMode','last','Name','biLSTM')
                fullyConnectedLayer(classAmount,'Name', 'fc')
                softmaxLayer('Name','softmax')
                classificationLayer('Name', 'classification')];
        end

        %カスタム損失関数用
        function layerSetting = createSingleLSTMLayerForCustomLossFunc(obj,inputSize, hiddenUnitAmount)
            arguments
                obj LayerSettingCreator
                inputSize {mustBeNumeric}
                hiddenUnitAmount {mustBeNumeric}
            end
            classAmount = length(unique(obj.trainData.labelStrings));
            layerSetting =  [ sequenceInputLayer(inputSize,'Name', 'Seq')
                %   bilstmLayer(hiddenUnitAmount,'OutputMode','sequence')
                %     bilstmLayer(hiddenUnitAmount,'OutputMode','sequence')
                %     bilstmLayer(hiddenUnitAmount,'OutputMode','sequence')
                bilstmLayer(hiddenUnitAmount,'OutputMode','last','Name','biLSTM')
                fullyConnectedLayer(classAmount,'Name', 'fc')
                softmaxLayer('Name','softmax')];
        end

        %複数入力用
        function layerSetting = createSingleSeqToProbLSTMLayer(obj,inputSize, hiddenUnitAmount)
            arguments
                obj LayerSettingCreator
                inputSize {mustBeNumeric}
                hiddenUnitAmount {mustBeNumeric}
            end
            classAmount = length(unique(obj.trainData.labelStrings));
            layerSetting =  [ sequenceInputLayer(inputSize,'Name', 'Seq')
                %   bilstmLayer(hiddenUnitAmount,'OutputMode','sequence')
                %     bilstmLayer(hiddenUnitAmount,'OutputMode','sequence')
                %     bilstmLayer(hiddenUnitAmount,'OutputMode','sequence')
                bilstmLayer(hiddenUnitAmount,'OutputMode','last','Name','biLSTM')
                fullyConnectedLayer(classAmount,'Name', 'fc')
                softmaxLayer('Name','softmax')
                classificationLayer];
        end
    end
end

