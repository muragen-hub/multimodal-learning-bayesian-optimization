function [data, label, representative, calibrationRepresentative] = createCalibratedFormedData(src, conditions, liquidConditions, stride, intervalBetweenData,dataWidth)
%CREATECALIBRATEDFORMEDDATA 今年から実験の前にキャリブレーションを行った. そのキャリブレーションのデータから, 上手いこと実験データを調整する.
%conditions liquidConditionの順番は昇順か降順かのどちらかにすること, でないとデータがおかしくなる.
%conditionsが[L1.5G1 L1.5G25 L1.5G50　L3G1 ...]ならliquidの方は[L1.5 L3 ...]とすること.
%[TODO] createFomrmedDataとの統合.

%どのように校正するのかについて, まず, 実験データを引いてから引き延ばすという処理が考えられたが, これはまずい. なぜなら,
%データの中での最大値が必ずしも液100ではないからである.
%次に, 各条件でのグラフを書いて, 平均を取って, その平均の, 他の流量条件とのずれを確認して全データに修正を加える.
%具体的にはL0のデータをそれぞれの実験データから引いてみる. ここで懸念だが, L100のデータがもしずれていなかった場合には,
%この引いてみることでのずれがL100の方に響いてしまう. つまり, 平行移動という訳ではない可能性があるということ.
%引いてみて, 上が分かっているので, L0からL100の間を100に合わせて拡大あるいは縮小する.


% [MEMO] 気相条件の数は全液相条件に対して等しいものと仮定する. 
% [MEMO] こちらは気相100%の場合の平均を持ってくる.
calibrationTimes = length(liquidConditions);
gasCalibrationSources = append(src,"/" ,"G30_before_", liquidConditions,"/ALLDATA.csv");
% [MEMO] 平均のみを取りたいのでこちらだけでよい.
gasCalibrationRawdata_capa = cell(1, calibrationTimes);
%データの形式として, ALLDATAの１列目が時間で２列目が静電容量
for i = 1:calibrationTimes
    tmp= readmatrix(gasCalibrationSources(i));
    gasCalibrationRawdata_capa{i} = tmp(1: end,2);
end
gasAverageArray =  cellfun(@mean, gasCalibrationRawdata_capa);

% [MEMO] 次にL100の方, つまりL~G0の方.
% [MEMO] こちらは液100%の場合の平均を持ってくる.
liquidCalibrationSources = append(src,"/", liquidConditions,"G0","/ALLDATA.csv");
liquidCalibrationRawdata_capa = cell(1, calibrationTimes);
%データの形式として, ALLDATAの１列目が時間で２列目が静電容量
for i = 1:calibrationTimes
    tmp= readmatrix(liquidCalibrationSources(i));
    liquidCalibrationRawdata_capa{i} = tmp(1: end,2);
end
liquidAverageArray = cellfun(@mean, liquidCalibrationRawdata_capa);
gasLiquidAverageDiff = liquidAverageArray - gasAverageArray;


%パスの作成. data以下に適切に実験データが配置されていることを確認. (gitignoreによりcloneしてきたままではdata以下には何も入っていない)
conditionsLength = length(conditions);
sources = append(src,"/", conditions,"/ALLDATA.csv");

rawdata_time = cell(1, conditionsLength);
rawdata_capa = cell(1, conditionsLength);

calibrationRefreshCounter = 0;
calibrationDividingNum = 1;
gasConditionsLength = conditionsLength/calibrationTimes;
calibrationDiffIndex = 0;

%データの形式として, ALLDATAの１列目が時間で２列目が静電容量
for i = 1:conditionsLength
    if mod(calibrationRefreshCounter, gasConditionsLength) == 0
        calibrationDiffIndex = calibrationDiffIndex + 1; %最初にこれを実行するので, 0-indexではない
        calibrationDividingNum = 1*10.^(-13)/gasLiquidAverageDiff(calibrationDiffIndex);%気相100と液相100の間の距離を100*10.^(-13)に揃える.
    end
    tmp= readmatrix(sources(i));
    rawdata_time{i} = tmp(51: end,1); %最初の数プロっトはCメータの関係上うまく取れていない可能性があるので除去. とりあえず50プロットほど除去しておく.
    rawdata_capa{i} = (tmp(51: end,2) - gasAverageArray(calibrationDiffIndex))*calibrationDividingNum; % 間隔を100*10.^(-13)にしたいので, 先に平均を引いておく必要がある. 
    calibrationRefreshCounter = calibrationRefreshCounter + 1;
end

min = transpose(cellfun(@min, rawdata_capa));
idx = transpose(min<0);
for i =1:conditionsLength
    if idx(i) == 1
        rawdata_capa{i} = rmoutliers(rawdata_capa{i}, 'ThresholdFactor',10); % エラーデータ(外れ値)を削除. これ本当に10で良いのか.
        rawdata_time{i} = rmoutliers(rawdata_time{i},'ThresholdFactor',10);
        mustBePositive(rawdata_capa{i});
    end
end

%代表値の取り出し
timeValue = transpose(cellfun(@numel,rawdata_time));
capaValue = transpose(cellfun(@numel,rawdata_capa));
average = transpose(cellfun(@mean, rawdata_capa));
min = transpose(cellfun(@min, rawdata_capa));
max = transpose(cellfun(@max, rawdata_capa));
%見やすくするため、テーブル配列を作成する
condition = transpose(conditions);
representative = table(condition, timeValue, capaValue,  max, min, average);
%テーブルに値は格納したので解放する
clear timeValue capaValue average min max

%一応キャリブレーションに用いた値のテーブルも取っておく.
calibrationRepresentative = table(transpose(liquidConditions),transpose(gasAverageArray), transpose(liquidAverageArray), transpose(gasLiquidAverageDiff));

% [MEMO] 多分関数分割するならここか.


% 加工済みデータ用のcell配列を用意する
data = cell(1, conditionsLength);
% 教師データYを用意する
label= cell(1,conditionsLength);

for i = 1:conditionsLength
    %データの実質的な一つの長さ. 学習用データを作る際に, 重なり条件を検証するためにデータ間に間隔(interval)を開ける.
    %strideはデータ間ではなく, データ列間のずらしであることに注意(株価予測で1時間ずつずらして一定時間のデータをとってきて学習用データを作るように.)
    oneDataSequence = intervalBetweenData*(dataWidth-1)+dataWidth;
    datasetAmount = (numel(rawdata_capa{i})-(oneDataSequence)) / stride+1;%データセットとして連続する元の生データからstrideずつずらしながらdataWidth分だけ取り出して作る時いくつ作成できるか. (長い列があって, そこから, 作成順に縦列に取った時, 階段上になるようにデータセットが作られる) matlabのforは整数型でなくとも切り捨てて回せる
    datasetAmount = int16(fix(datasetAmount)); %strideを1でない数にした場合で, 上方向に丸められてしまった場合に, indexがオーバーしているエラーを吐く.
    data{i} = zeros(datasetAmount, dataWidth);
    label{i} = string(zeros(datasetAmount, 1));

    % data_width，strideに合わせて加工
    for j=1:datasetAmount
        %データを特に抜かすことなく取るならintervalBetweenDataには0と入ることが期待されるが,
        %matlabの文法上(1:0:8)などは空の配列が返されてしまうため, ここには+1を入れて調整する.
        data{i}(j,1:dataWidth)=rawdata_capa{i}(1+(j-1)*stride:intervalBetweenData+1:(j-1)*stride+oneDataSequence);                      %(1+(j-1)*stride:(j-1)*stride+dataWidth);
        label{i}(j,1)=conditions(i);
    end
    label{i}=categorical(label{i});%categoricalにしてメモリ節約
end
end

