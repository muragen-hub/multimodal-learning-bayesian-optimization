function [processedTrain, processedTest] = multiVectorStandardize(trainData, testData)
%STANDARDIZE 訓練前の標準化を行う関数
arguments
    trainData TrainTestData
    testData TrainTestData
end
% データの標準化
% 平均が0、分散が1になるようにデータを標準化する。予測時も学習時と同様のパラメータを用いて標準化する必要がある。

flatProcessedTrainData = cell2mat(trainData.data);
flatProcessedTestData = cell2mat(testData.data);

mu = mean(flatProcessedTrainData,'all'); %平均
sig = std(flatProcessedTestData,0,'all'); %標準偏差


flatProcessedTrainData = (flatProcessedTrainData - mu) / sig; %（標準化したい値 - 平均）/ 標準偏差
flatProcessedTestData = (flatProcessedTestData - mu) / sig;

%X側(訓練側)をセル配列にする

%ここで, 上のセル配列は元々n次元の特徴があったものを数行に渡って単純に並べることを全てのセルについて行ったものなので,
%戻すときは工夫する必要がある.

characteristicVectorDimention = size(trainData.data{1},1);

trainLength = length(trainData.data);
testLength = length(testData.data);

structedProcessedTrainData = cell(trainLength,1);
structedProcessedTestData = cell(testLength,1);

if (trainLength > testLength)
    for j = 1:testLength
        structedProcessedTrainData{j} = flatProcessedTrainData(j:j+characteristicVectorDimention-1,:);
        structedProcessedTestData{j} = flatProcessedTestData(j:j+characteristicVectorDimention-1,:);
    end

    for j = testLength+1:trainLength
        structedProcessedTrainData{j} = flatProcessedTrainData(j:j+characteristicVectorDimention-1,:);
    end
else
    disp('訓練とテストデータの数がひっくり返っていないか確認してください')
    for j = 1:trainLength
        structedProcessedTrainData{j} = flatProcessedTrainData(j:j+characteristicVectorDimention-1,:);
        structedProcessedTestData{j} = flatProcessedTestData(j:j+characteristicVectorDimention-1,:);
    end

    for j = trainLength+1:testLength
        structedProcessedTestData{j} = flatProcessedTestData(j:j+characteristicVectorDimention-1,:);
    end
end 
clear flatProcessedTrainData flatProcessedTestData;

processedTrain = TrainTestData(structedProcessedTrainData, trainData.label,trainData.minimumLength,trainData.conditionStrings,trainData.labelStrings);
processedTest = TrainTestData(structedProcessedTestData, testData.label,testData.minimumLength,testData.conditionStrings,testData.labelStrings);

clear trainData testData;
end

