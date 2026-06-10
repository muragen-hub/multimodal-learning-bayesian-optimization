function [TimeTabledDataCell, representative] = createCalibratedConstFreqTimeTable(src, conditions,liquidConditions, measuredFreq)
%フィルタをかませるに当たって, はずれ値除去, 等間隔サンプリング, timeTableの生成を先に行う.
%src: データの日時
%conditions: どの条件で判別するかのstring配列
%measuredFewq: 理想的な測定周波数

%パスの作成. data以下に適切に実験データが配置されていることを確認. (gitignoreによりcloneしてきたままではdata以下には何も入っていない)
conditionsLength = length(conditions);
sources = append(src,"/", conditions,"/ALLDATA.csv");

TimeTabledDataCell = cell(1, conditionsLength);

%timeとcapaの二つの個数を取っておくのは多分個数違いがないかのデバッグ用.
timeArrayLength =zeros(conditionsLength,1);
capaArrayLength =zeros(conditionsLength,1);
average =zeros(conditionsLength,1);
minimum =zeros(conditionsLength,1);
maximum =zeros(conditionsLength,1);

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
    liquidCalibrationRawdata_capa{i} = rmoutliers(tmp(1: end,2)); %液の方はなんかぶれることがあるため, 外れ値を削除してから平均を取る
end

liquidAverageArray = cellfun(@mean, liquidCalibrationRawdata_capa);
gasLiquidAverageDiff = liquidAverageArray - gasAverageArray;

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
    % 0.02秒が2000となっているため, 記録の時間の単位は10μSである.
    tmp(:,1) = (tmp(:,1) - tmp(1,1))/10^5;
    time = tmp(:,1);
    capa = (tmp(:,2) - gasAverageArray(calibrationDiffIndex))*calibrationDividingNum; % 間隔を100*10.^(-13)にしたいので, 先に平均を引いておく必要がある. 
    timeArrayLength(i) = length(time);
    capaArrayLength(i) = length(capa);
    average(i) = mean(capa);
    minimum(i) = min(capa);
    maximum(i) = max(capa);
    TimeTabledDataCell{i}= timetable(seconds(time), capa); %Timetableはdurationでないといけない.
    TimeTabledDataCell{i} = rmoutliers(TimeTabledDataCell{i}, 'ThresholdFactor',10); % エラーデータ(外れ値)を削除. これ本当に10で良いのか
    TimeTabledDataCell{i} = retime(TimeTabledDataCell{i},'regular','linear','SampleRate',measuredFreq); %おかしなデータは線形内挿.
    mustBePositive(capa);
    calibrationRefreshCounter = calibrationRefreshCounter + 1;
end
representative = table(transpose(conditions), timeArrayLength, capaArrayLength,  maximum, minimum, average);
end

