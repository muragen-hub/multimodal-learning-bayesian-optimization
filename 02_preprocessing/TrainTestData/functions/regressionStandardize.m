function  [processedTrain, processedTest] = regressionStandardize(trainData, testData)
%STANDARDIZE 訓練前の標準化を行う関数
arguments
   trainData RegressionTrainTestData % そろそろRegressionTrainTestDataとTrainTestDataを統合して扱えるようにすべき．
   testData RegressionTrainTestData
end
% データの標準化. 特徴量ごとに行う. 
% 平均が0、分散が1になるようにデータを標準化する。予測時も学習時と同様のパラメータを用いて標準化する必要がある。

%訓練データの方から
inputSize = size(trainData.trainData{1},1);
dataWidth = size(trainData.trainData{1},2);
trainDataAmount = size(trainData.trainData,1);

deployedTrainData = cell2mat(trainData.trainData);
deployedTrainDataAmount = size(deployedTrainData,1); 
standardizedTrainData = zeros(trainDataAmount,dataWidth,inputSize);
muArray = zeros(1,inputSize);
sigArray=zeros(1,inputSize);
for featuresNum = 1:inputSize
    idx = featuresNum:inputSize:deployedTrainDataAmount;  
    %thatFeaturesMatrix = deployedTrainData(idx,:);
    %その特徴量だけを拾ってきたmatrixを作る.  これ重い. 

    mu = mean(deployedTrainData(idx,:),'all'); %平均
    sig = std(deployedTrainData(idx,:),0,'all'); %標準偏差

    standardizedTrainData(:,:,featuresNum) = (deployedTrainData(idx,:) - mu) ./sig;
    muArray(featuresNum)=mu;
    sigArray(featuresNum)=sig;
end
clear  deployedTrainData;
standardizedTrainData = num2cell(standardizedTrainData,[2 3]);
standardizedTrainData =  cellfun(@(x) permute(x,[3,2,1]), standardizedTrainData,'uniformOutput',false);
standardizedTrainData =  cellfun(@(x) squeeze(x),standardizedTrainData ,'uniformOutput',false);
            
standardizedTrainValueLabelData = cellfun(@(x) (x -mu)./sig,trainData.valueLabelData,'uniformOutput',false);
processedTrain = RegressionTrainTestData(standardizedTrainData,standardizedTrainValueLabelData,trainData.label,trainData.minimumLength,trainData.conditionStrings,trainData.labelStrings,trainData.accurateLiquidFlowRate,trainData.accurateGasFlowRate,"mu",muArray,"sig",sigArray);

clear deployedTrainData thatFeaturesMatrix standardizedTrainData  standardizedTrainValueLabelData 

%テストデータの方
testDataAmount = size(testData.trainData,1);
deployedTestData = cell2mat(testData.trainData);
deployedTestDataAmount = size(deployedTestData,1);
standardizedTestData = zeros(testDataAmount,dataWidth,inputSize);
for featuresNum = 1:inputSize
    idx = featuresNum:inputSize:deployedTestDataAmount;

    mu = mean(deployedTestData(idx,:),'all'); %平均
    sig = std(deployedTestData(idx,:),0,'all'); %標準偏差

    standardizedTestData(:,:,featuresNum) = (deployedTestData(idx,:)- mu) ./sig;
    muArray(featuresNum)=mu;
    sigArray(featuresNum)=sig;
end
clear  deployedTestData;
standardizedTestData = num2cell(standardizedTestData,[2 3]);
standardizedTestData =  cellfun(@(x) permute(x,[3,2,1]), standardizedTestData,'uniformOutput',false);
standardizedTestData =  cellfun(@(x) squeeze(x),standardizedTestData ,'uniformOutput',false);
            
standardizedTestValueLabelData = cellfun(@(x) (x -mu)./sig,testData.valueLabelData,'uniformOutput',false);
processedTest= RegressionTrainTestData(standardizedTestData,standardizedTestValueLabelData,testData.label,testData.minimumLength,testData.conditionStrings,testData.labelStrings,testData.accurateLiquidFlowRate,testData.accurateGasFlowRate,"mu",muArray,"sig",sigArray);
end
