classdef TrainTestPreProcessor
    %TRAINTESTPREPROCESSOR このクラスの概要をここに記述
    %   詳細説明をここに記述

    properties
        preProcessorCore
    end

    methods
        function obj = TrainTestPreProcessor(funcs)
            arguments
                funcs (1,:) cell
            end
            obj.preProcessorCore = funcs;
        end

        function [modifiedTrain, modifiedTest] = process(obj,train, test)
            arguments
                obj TrainTestPreProcessor
                train TrainTestData
                test TrainTestData
            end
            processingTrainData = train;
            processingTestData  = test;
            for i = 1:length(obj.preProcessorCore)
                [processingTrainData,processingTestData] = obj.preProcessorCore{i}(processingTrainData,processingTestData);
            end
            modifiedTrain = processingTrainData.data;
            modifiedTest = processingTestData.data;
        end

        function [modifiedTrain, modifiedTest] = cellInputProcess(obj,train, test)
            arguments
                obj TrainTestPreProcessor
                train (:, :) cell
                test (:, :) cell
            end
            processingTrainData = train;
            processingTestData  = test;
            for i = 1:length(obj.preProcessorCore)
                [processingTrainData,processingTestData] = obj.preProcessorCore{i}(processingTrainData,processingTestData);
            end
            modifiedTrain = processingTrainData;
            modifiedTest = processingTestData;
        end

        function [modifiedTrain, modifiedTest] = regressionDataProcess(obj,train, test)
            arguments
                obj TrainTestPreProcessor
                train RegressionTrainTestData
                test RegressionTrainTestData
            end
            processingTrainData = train;
            processingTestData  = test;
            for i = 1:length(obj.preProcessorCore)
                [processingTrainData,processingTestData] = obj.preProcessorCore{i}(processingTrainData,processingTestData);
            end
            modifiedTrain = RegressionTrainTestData(processingTrainData.trainData,processingTrainData.valueLabelData ,processingTrainData.label,processingTrainData.minimumLength,processingTrainData.conditionStrings,processingTrainData.labelStrings,processingTrainData.accurateLiquidFlowRate,processingTrainData.accurateGasFlowRate,"mu",processingTrainData.mu,"sig",processingTrainData.sig);
            modifiedTest = RegressionTrainTestData(processingTestData.trainData, processingTestData.valueLabelData,processingTestData.label,processingTestData.minimumLength,processingTestData.conditionStrings,processingTestData.labelStrings,processingTestData.accurateLiquidFlowRate,processingTestData.accurateGasFlowRate,"mu",processingTestData.mu,"sig",processingTestData.sig);
        end
    end
end

