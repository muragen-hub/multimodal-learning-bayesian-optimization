function[formedTrainData, formedTrainLabel, formedTestData, formedTestLabel] = createTrainTestData(conditions, basicTrainData, basicTrainLabel, basicTestData, basicTestLabel)
    %ラベル付けされたデータ群から実際に学習とモデルの精度検証テストに用いるデータを作成する
    %basicTrainData：学習に用いるデータのセル配列
    %basicTrainLabel：学習に用いるデータと対応するラベルのセル配列（データの方との順番の対応に注意）
    %basicTestData：テストに用いるデータのセル配列
    %basicTestLabel：テストに用いるデータと対応するラベルのセル配列（データの方との順番の対応に注意）

    trainData=cell(1,length(conditions));
    trainLabel=cell(1,length(conditions));
    testData=cell(1,length(conditions));
    testLabel=cell(1,length(conditions));

    conditionsLength = length(conditions);
    dataWidth = numel(basicTrainData{1}{1}(1,:));

    %各流量条件ごとにセル配列の中身に連ねていく.
    %前提としてbasicTrainDataなどは1つ以上の日時のセル配列であるという点に注意.例えば{data_1030, data_1127}など
    
    for i=1:conditionsLength
        for j=1:numel(basicTrainData)
            trainData{i}=vertcat(trainData{i},basicTrainData{j}{i});
        end

        for j=1:numel(basicTestData)
            testData{i}=vertcat(testData{i},basicTestData{j}{i});
        end

        for j=1:numel(basicTrainLabel)
            trainLabel{i}=vertcat(trainLabel{i},basicTrainLabel{j}{i});
        end

        for j=1:numel(basicTestLabel)
            testLabel{i}=vertcat(testLabel{i},basicTestLabel{j}{i});
        end    
    end
    

    %すべての流量条件で訓練データ数を合わせる.
    trainDataMiniMumAmount = numel(trainData{1}(:,1));

    %最小の訓練データ数を拾ってくる
    for i=1:conditionsLength
        if numel(trainData{i}(:,1))<trainDataMiniMumAmount
            trainDataMiniMumAmount=numel(trainData{i}(:,1));
        end
    end
    
    for i=1:conditionsLength
        if numel(trainData{i}(:,1))>=trainDataMiniMumAmount
            %元々の全インデックスの範囲からtrainDataAmount個だけ一意なインデックスを生成.これは行ってよいのかこれを行うことで時系列ということが保証されなくなってしまうしソートしてもその間隔がおかしくなってしまう
            %データの日付が一つだけの時に行うなら先頭からとるべきであるし複数の日時にまたがるならもはや時系列というものが意味をなさなくなるため日付ごとのアンサンブル平均を取る方向にシフトしたほうが良くないか
            %最小のデータ数に合わせるようにして残りのあまりの部分は切り捨てるように変更.
            %idx=randperm(numel(trainData{i}(:,1)),trainDataMiniMumAmount);
            %trainData{i}=trainData{i}(idx,:);
            %MATLABの配列のインデックスは(x,y)とあったら縦がxである. 
            %trainLabel{i}=trainLabel{i}(idx,:);
            trainData{i}=trainData{i}(1:trainDataMiniMumAmount,:);
            trainLabel{i}=trainLabel{i}(1:trainDataMiniMumAmount,:);
        end
    end
    
     %すべての流量条件でテストデータ数を合わせる. 
     %ここは流量の方だけ取ってくればよいのでは? なぜテストデータの側も取ってきているのか.
     %と思ったけどテスト用のは基本的に別実取得のデータなので違うのは当たり前であった.
    testDataAmount = numel(testData{1}(:,1));
    %最小のテストデータ数を拾ってくる
    for i=1:conditionsLength
        if numel(testData{i}(:,1))<testDataAmount 
            testDataAmount=numel(testData{i}(:,1));
        end
    end
    
    for i=1:conditionsLength
        if numel(testData{i}(:,1))>=testDataAmount 
            %idx=randperm(numel(testData{i}(:,1)),testDataAmount);
            testData{i}=testData{i}(1:testDataAmount ,:);
            testLabel{i}=testLabel{i}(1:testDataAmount ,:);
        end
    end
    
    % 1 * 流量条件個数のcell配列からdataWidthのデータの最小の個数*流量条件個数 * dataWidthに変更
    zeros(trainDataMiniMumAmount*conditionsLength, dataWidth);
    formedTrainData=zeros(trainDataMiniMumAmount*conditionsLength, dataWidth);
    formedTrainLabel=strings(trainDataMiniMumAmount*conditionsLength,1);

    formedTestData=zeros(testDataAmount*conditionsLength, dataWidth);
    formedTestLabel=strings(testDataAmount*conditionsLength,1);
    %最初からデータの最小個数*流量条件の個数*dataWidthの配列に変更してしまったほうがよいのでは
    
    for i=1:conditionsLength
        formedTestData((i-1)*testDataAmount+1: i*testDataAmount, :) = testData{i};
        formedTestLabel((i-1)*testDataAmount+1: i*testDataAmount, :) = testLabel{i};

        formedTrainData((i-1)*trainDataMiniMumAmount+1: i*trainDataMiniMumAmount, :) = trainData{i};
        formedTrainLabel((i-1)*trainDataMiniMumAmount+1: i*trainDataMiniMumAmount, :) = trainLabel{i};
    end
    
    %categoriesがわかっているカテゴリカル配列の任意の長さでの初期化の方法を探し出せなかったので
    formedTestLabel = categorical(formedTestLabel);
    formedTrainLabel = categorical(formedTrainLabel);
    
    % メモリ節約のためX_, Y_は解放
    clear trainData trainLabel testData testLabel;
    
    % データの標準化
    % 平均が0、分散が1になるようにデータを標準化する。予測時も学習時と同様のパラメータを用いて標準化する必要がある。
    
    mu = mean(formedTrainData,'all'); %平均
    sig = std(formedTrainData,0,'all'); %標準偏差

    formedTrainData = (formedTrainData - mu) / sig; %（標準化したい値 - 平均）/ 標準偏差 
    formedTestData = (formedTestData - mu) / sig;

    %X側(訓練側)をセル配列にする
    formedTrainData=num2cell(formedTrainData,2);
    formedTestData=num2cell(formedTestData,2);
end

