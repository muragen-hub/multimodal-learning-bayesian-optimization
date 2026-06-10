%%  0506と0514 stride5
%将来的にはDataStoreにするべき. splitEachLabelで簡単に学習用とテスト用とかが分けられる.
clear;
close all hidden;
conditions_6_22= ["L6G1"  "L6G5" "L6G10" "L6G15" "L6G20" "L6G25" "L6G30" "L6G35" "L6G40" "L6G45" "L6G50" "L3G1"  "L3G5" "L3G10" "L3G15" "L3G20" "L3G25" "L3G30" "L3G35" "L3G40" "L3G45" "L3G50"];
classAmount = length(conditions_6_22);
stride=5;
intervalBetweenData =0;
dataWidth=300;
inputSize=1;
hiddenUnitsAmount=320;
maxEpochs = 15;
miniBatchSize = 64;
frequencynumber = 100;

[data_6_22_0506, label_6_22_0506, ~]  = createFormedData("resources/data/20210506", conditions_6_22, stride,intervalBetweenData ,dataWidth);
[data_6_22_0514, label_6_22_0514, ~]  = createFormedData("resources/data/20210514", conditions_6_22, stride,intervalBetweenData, dataWidth);

[trainData, trainLabel, testData, testLabel] = createTrainTestData(conditions_6_22, {data_6_22_0514}, {label_6_22_0514},{data_6_22_0506},{label_6_22_0506});
[prediction, layers,trainedNet] = activateLSTM(trainData, trainLabel, testData, testLabel, classAmount, inputSize, hiddenUnitsAmount, maxEpochs, miniBatchSize, frequencynumber);
outputGraph(conditions_6_22, prediction, testLabel, "overlappingConditionAccuracy/train0514_test0506_condition22_stride5/");

lgraph = layerGraph(layers);
figure
plot(lgraph)

biLSTMLayerName = 'biLSTM';
fullConnectLayerName = 'fc';
softmaxLayerName = 'softmax'; 

biLSTMActivation = activations(trainedNet, testData,biLSTMLayerName,"OutputAs","rows");
fullConnectActivation = activations(trainedNet, testData, fullConnectLayerName,"OutputAs","rows");
softmaxActivation = activations(trainedNet, testData , softmaxLayerName,"OutputAs","rows");
rng default %乱数初期化

biLSTMtsne = tsne(biLSTMActivation);
fullconnecttsne = tsne(fullConnectActivation);
softmaxtsne = tsne(softmaxActivation);

markerSize = 7;
figure;

subplot(1,3,1);
gscatter(biLSTMtsne(:,1),biLSTMtsne(:,2),testLabel, ...
    [],'.',markerSize);
title("biLSTM層の次元圧縮結果");

subplot(1,3,2);
gscatter(fullconnecttsne(:,1),fullconnecttsne(:,2),testLabel, ...
    [],'.',markerSize);
title("全結合層の次元圧縮結果");

subplot(1,3,3);
gscatter(softmaxtsne(:,1),softmaxtsne(:,2),testLabel, ...
    [],'.',markerSize);
title("ソフトマックス層の次元圧縮結果");

%% 関数のテスト
clear;
close all hidden;
conditions_6_22= ["L6G1"  "L6G5" "L6G10" "L6G15" "L6G20" "L6G25" "L6G30" "L6G35" "L6G40" "L6G45" "L6G50" "L3G1"  "L3G5" "L3G10" "L3G15" "L3G20" "L3G25" "L3G30" "L3G35" "L3G40" "L3G45" "L3G50"];
classAmount = length(conditions_6_22);
stride=5;
intervalBetweenData =0;
dataWidth=300;
inputSize=1;
hiddenUnitsAmount=320;
maxEpochs = 15;
miniBatchSize = 64;
frequencynumber = 100;

[data_6_22_0506, label_6_22_0506, ~]  = createFormedData("resources/data/20210506", conditions_6_22, stride,intervalBetweenData ,dataWidth);
[data_6_22_0514, label_6_22_0514, ~]  = createFormedData("resources/data/20210514", conditions_6_22, stride,intervalBetweenData, dataWidth);

[trainData, trainLabel, testData, testLabel] = createTrainTestData(conditions_6_22, {data_6_22_0514}, {label_6_22_0514},{data_6_22_0506},{label_6_22_0506});
[prediction, layers,trainedNet] = activateLSTM(trainData, trainLabel, testData, testLabel, classAmount, inputSize, hiddenUnitsAmount, maxEpochs, miniBatchSize, frequencynumber);
outputGraph(conditions_6_22, prediction, testLabel, "overlappingConditionAccuracy/train0514_test0506_condition22_stride5/");

tsneWrapper(conditions_6_22, layers, trainedNet, testData, testLabel, "overlappingConditionAccuracy/train0514_test0506_condition22_stride5/");


