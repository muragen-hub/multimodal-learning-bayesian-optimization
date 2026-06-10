function [trainData, trainLabel, testData, testLabel] = createDividedTrainTestData(formedData, formedLabel, trainTestRatio)
%CREATEDIVIDEDTRAINTESTDATA この関数の概要をここに記述
%ある日に取ったデータから, 適当な割合でデータを分割し, 訓練とテストデータを作成する関数
%formedData, formedLabel: dataWidth単位で各流量条件ごとにセルでまとめたデータ
%TrainTestRatio: 全体のデータに対して, TestDataに使う割合 

%wikipediaより　時系列データの場合、{\displaystyle w_{1}}w_{1} を訓練データの長さ、{\displaystyle w_{2}}{\displaystyle w_{2}} をテストデータの長さとし、
%時系列解析の場合
%x番目の訓練データの範囲：{\displaystyle w_{2}x}{\displaystyle w_{2}x} ～ {\displaystyle w_{2}x+w_{1}}{\displaystyle w_{2}x+w_{1}}
%x番目のテストデータの範囲：{\displaystyle w_{2}x+w_{1}}{\displaystyle w_{2}x+w_{1}} ～ {\displaystyle w_{2}x+w_{1}+w_{2}}{\displaystyle w_{2}x+w_{1}+w_{2}}
%上記になるようにテストデータが訓練データよりも未来の時刻になるようにスライディングウィンドウにて交差検証する方法がある。時系列は時間の流れで因果関係・相関関係があるため、テストデータは訓練データよりも未来の時刻にしないといけない。
%
%また、以下のように訓練データを先頭から使い徐々に長くする方法もある。
%
%x番目の訓練データの範囲：{\displaystyle 0}{\displaystyle 0} ～ {\displaystyle w_{2}(x+1)}{\displaystyle w_{2}(x+1)}
%x番目のテストデータの範囲：{\displaystyle w_{2}(x+1)}{\displaystyle w_{2}(x+1)} ～ {\displaystyle w_{2}(x+2)}{\displaystyle w_{2}(x+2)}
%ただ, 深層学習で交差検証すると死ぬと思うので, セル配列で受けた別実取得のデータをvertcatで全ての条件でまとめて,
%長さをそろえた後に,適当な比率で, 例えば9:1などでホールドアウト検証するべきか.

%なお，訓練データセットとテ
%ストデータセットに同日取得のデータセットを用いる場合 (例えば両方ともに⃝1 を用いる場合など) は，
%元のデータセットをあらかじめ 9:1 に分割し，それぞれを訓練データセット，テストデータセットとする
%ことでデータが重複しないようにした(2019 樺山)
%とのことからホールドアウト検証をしたという訳ではないらしい. あくまでも同じ日のデータを使う場合.

%rng('default') % 再現性が必要な時はこれをonにする. 
conditionsLength = length(formedData);
trainData = cell(1, conditionsLength);
trainLabel = cell(1, conditionsLength);
testData = cell(1, conditionsLength);
testLabel = cell(1, conditionsLength);

for i = 1:conditionsLength
    n = length(formedData{i});
    hpartition = cvpartition(n,'Holdout',trainTestRatio); % Nonstratified partition
    idxTrain = training(hpartition);
    trainData{i} = formedData{i}(idxTrain,:);
    trainLabel{i} = formedLabel{i}(idxTrain,:);
    idxTest = test(hpartition);
    testData{i} = formedData{i}(idxTest,:);
    testLabel{i} = formedLabel{i}(idxTest,:);
end
end

