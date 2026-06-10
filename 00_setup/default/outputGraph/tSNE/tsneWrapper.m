function []  = tsneWrapper(condition,layers,trainedNet,testData, testLabel ,folderName)
%TSNELAPPER 深層学習における各層の可視化としてのt-sneの結果の図を出力してくれるラッパ関数.
%現在は仮実装であり, もし, 深層学習の層の構造を変化させたならこちらの実装も変える必要がある.(主にactivations関数を使うところ.
%   

dirName = append("pictures/",folderName);
    if not(exist( dirName ,'dir'))
        mkdir( dirName )
    end

lgraph = layerGraph(layers);
figure
plot(lgraph)
saveas(gcf, append( dirName , "Layer Map.fig"))

%ここべた書き
biLSTMLayerName = 'biLSTM';
fullConnectLayerName = 'fc';
softmaxLayerName = 'softmax'; 

biLSTMActivation = activations(trainedNet, testData,biLSTMLayerName,"OutputAs","rows");
fullConnectActivation = activations(trainedNet, testData, fullConnectLayerName,"OutputAs","rows");
softmaxActivation = activations(trainedNet, testData , softmaxLayerName,"OutputAs","rows");
rng default %乱数初期化. これで, t-SNEの再現性ができるらしい.

biLSTMtsne = tsne(biLSTMActivation,'Algorithm','barneshut','NumPCAComponents',50);
fullconnecttsne = tsne(fullConnectActivation,'Algorithm','barneshut','NumPCAComponents',20);
softmaxtsne = tsne(softmaxActivation,'Algorithm','barneshut','NumPCAComponents',10);

predictionLabel=classify(trainedNet,testData); %これでまず誤判別されたものを持ってくる.
misclassifiedIndex = predictionLabel== testLabel;

%ここでは曖昧さは最も高い分類値の50%異常に二番目に高い値が分類されている場合とする.
R = maxk(softmaxActivation,2,2); %各行の中で最も大きな2つの値を拾ってくる.
ambiguity = R(:,2)./R(:,1);
ambiguityIndex = ambiguity >=0.5;

% massara
markerSize = 5;
figure;

subplot(1,3,1);
hold on;
gscatter(biLSTMtsne(:,1),biLSTMtsne(:,2),testLabel, ...
    [],'.',markerSize);
title("biLSTM層の次元圧縮結果");
legend(condition,'Location','northeastoutside');
hold off;

subplot(1,3,2);
hold on;
gscatter(fullconnecttsne(:,1),fullconnecttsne(:,2),testLabel, ...
    [],'.',markerSize);
title("全結合層の次元圧縮結果");
legend(condition,'Location','northeastoutside')

hold off;

subplot(1,3,3);
hold on;
gscatter(softmaxtsne(:,1),softmaxtsne(:,2),testLabel, ...
    [],'.',markerSize);
title("ソフトマックス層の次元圧縮結果");
legend(condition,'Location','northeastoutside')

hold off;
saveas(gcf, append( dirName , "t-sne result  vanilla.fig"))


%まずは誤判別から
figure;
subplot(1,3,1);
hold on;
gscatter(biLSTMtsne(:,1),biLSTMtsne(:,2),testLabel, ...
    [],'.',markerSize);
title("biLSTM層の次元圧縮結果");
legend(condition,'Location','northeastoutside');
l = legend;
scatter(biLSTMtsne(misclassifiedIndex, 1), biLSTMtsne(misclassifiedIndex, 2), ...
    markerSize,'k','d','LineWidth',0.01);
l.String{end} = 'misClasified';
hold off;

subplot(1,3,2);
hold on;
gscatter(fullconnecttsne(:,1),fullconnecttsne(:,2),testLabel, ...
    [],'.',markerSize);
title("全結合層の次元圧縮結果");
legend(condition,'Location','northeastoutside')

l = legend;
scatter(fullconnecttsne(misclassifiedIndex, 1), fullconnecttsne(misclassifiedIndex, 2), ...
    markerSize,'k','d','LineWidth',0.01);
l.String{end} = 'misClasified';
hold off;

subplot(1,3,3);
hold on;
gscatter(softmaxtsne(:,1),softmaxtsne(:,2),testLabel, ...
    [],'.',markerSize);
title("ソフトマックス層の次元圧縮結果");
legend(condition,'Location','northeastoutside')

l = legend;
scatter(softmaxtsne(misclassifiedIndex, 1), softmaxtsne(misclassifiedIndex, 2), ...
    markerSize,'k','d','LineWidth',0.01);
l.String{end} = 'misClasified';

hold off;
saveas(gcf, append( dirName , "t-sne result misClassified.fig"))

%次に曖昧さについて

figure;
subplot(1,3,1);
hold on;
gscatter(biLSTMtsne(:,1),biLSTMtsne(:,2),testLabel, ...
    [],'.',markerSize);
title("biLSTM層の次元圧縮結果");
legend(condition,'Location','northeastoutside');
l = legend;
scatter(biLSTMtsne(ambiguityIndex, 1), biLSTMtsne(ambiguityIndex, 2), markerSize,...
    'black','LineWidth',0.01);
l.String{end} = 'Ambiguity';
hold off;

subplot(1,3,2);
hold on;
gscatter(fullconnecttsne(:,1),fullconnecttsne(:,2),testLabel, ...
    [],'.',markerSize);
title("全結合層の次元圧縮結果");
legend(condition,'Location','northeastoutside')

l = legend;

scatter(fullconnecttsne(ambiguityIndex, 1), fullconnecttsne(ambiguityIndex, 2),markerSize, ...
    'black','LineWidth',0.01);
l.String{end} = 'Ambiguity';
hold off;

subplot(1,3,3);
hold on;
gscatter(softmaxtsne(:,1),softmaxtsne(:,2),testLabel, ...
    [],'.',markerSize);
title("ソフトマックス層の次元圧縮結果");
legend(condition,'Location','northeastoutside')

l = legend;
scatter(softmaxtsne(ambiguityIndex, 1), softmaxtsne(ambiguityIndex, 2), markerSize, ...
    'black','LineWidth',0.01);
l.String{end} = 'Ambiguity';
hold off;
saveas(gcf, append( dirName , "t-sne result ambiguity.fig"))



end





