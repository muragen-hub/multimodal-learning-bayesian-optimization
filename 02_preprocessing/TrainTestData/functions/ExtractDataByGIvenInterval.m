function  func = ExtractDataByGIvenInterval(dataInterval)
%STANDARDIZE TrainTestDataから固定Intervalでデータを抽出する. (PDやSHAPのため.)
arguments
    dataInterval {mustBeInteger,mustBePositive}
end

    function [processedTrain, processedTest] = ExtractDataByGIvenIntervalCore(trainData, testData)
        extracted = trainData.trainData(1:dataInterval:end);
        conditionLength = length(trainData.conditionStrings);
        processedTrain = RegressionTrainTestData(extracted,trainData.valueLabelData(1:dataInterval:end),trainData.label(1:dataInterval:end),length(extracted)/conditionLength,trainData.conditionStrings,trainData.labelStrings,trainData.accurateLiquidFlowRate(1:dataInterval:end),trainData.accurateGasFlowRate(1:dataInterval:end),"mu",trainData.mu,"sig",trainData.sig);
        
        extracted = testData.trainData(1:dataInterval:end);
        conditionLength = length(testData.conditionStrings);
        processedTest= RegressionTrainTestData(extracted,testData.valueLabelData(1:dataInterval:end),testData.label(1:dataInterval:end),length(extracted)/conditionLength,testData.conditionStrings,testData.labelStrings,testData.accurateLiquidFlowRate(1:dataInterval:end),testData.accurateGasFlowRate(1:dataInterval:end),"mu",testData.mu,"sig",testData.sig);
    end

func = @ExtractDataByGIvenIntervalCore;
end

