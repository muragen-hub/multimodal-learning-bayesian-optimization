function [prediction, layers,trainedNet] = activateLSTM_2BLSTM(trainData, trainLabel, testData, testLabel, classAmount, inputSize, hiddenUnitAmount, maxEpochs, miniBatchSize, frequencynumber)
%LSTMによる学習を行いそのモデルの精度を返す.
%引数
%trainData, trainLabel, testData, testLabel, 
%classAmount, inputSize, hiddenUnitAmount, 
%maxEpochs, miniBatchSize, frequencynumber

layers = [ sequenceInputLayer(inputSize,'Name', 'Seq')
   bilstmLayer(hiddenUnitAmount,'OutputMode','sequence')
%     bilstmLayer(hiddenUnitAmount,'OutputMode','sequence')
%     bilstmLayer(hiddenUnitAmount,'OutputMode','sequence')
    bilstmLayer(hiddenUnitAmount,'OutputMode','last','Name','biLSTM')
    fullyConnectedLayer(classAmount,'Name', 'fc')
    softmaxLayer('Name','softmax')
    classificationLayer('Name', 'classification')];

stopnumber = round(length(trainData)/(miniBatchSize*frequencynumber))*5;

if stopnumber == 0
    disp('データ数が不足しています。stopnumber が０になっていますので, stopNumberはInfで開始されます')
    stopnumber = Inf;
end

% optionについて詳しく調べる
options = trainingOptions('adam', ...
    'ExecutionEnvironment','auto', ...
    'GradientThreshold',1, ...
    'MaxEpochs',maxEpochs, ...
    'ValidationData',{testData, testLabel}, ... %検証用データ. テストデータとは厳密には異なることに注意. (最後のミニバッチにおける検証用データがテストデータに相当か. 本来は恐らく別にするべき.)
    'ValidationFrequency',frequencynumber, ...％訓練何回ごとにテストデータと突き合わせて正確さを測定するか
    'ValidationPatience',stopnumber, ... %損失が更新されなくなったら終了.の基準
    'MiniBatchSize',miniBatchSize, ...
    'Shuffle','every-epoch', ... %前はevery-epochになっていたが, 時系列データなら, ここもneverにすべきではと思ったがneverで行った所, 全く意味をなさない学習結果が帰ってきた. これはシーケンスの途中で条件が変わってしまっているものも含むためであるか. これについて, ただ, 一つの流動様式についての精度は高く出るので, モデルを変えてもいいかもしれない.
    'Verbose',0, ... % 1にすると,コマンドライン表示
    'VerboseFrequency',2, ... 
    'Plots','training-progress');% 進捗表示


% 学習
net = trainNetwork(trainData,trainLabel,layers,options);

prediction=classify(net,testData);

trainedNet = net;

acc=sum(prediction==testLabel)./numel(testLabel);
disp(acc);
 
 































