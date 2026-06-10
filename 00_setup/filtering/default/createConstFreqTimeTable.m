function [TimeTabledDataCell, representative] = createConstFreqTimeTable(src, conditions, measuredFreq)
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
    %データの形式として, ALLDATAの１列目が時間で２列目が静電容量
    for i = 1:conditionsLength
        tmp= readmatrix(sources(i));
        % 0.02秒が2000となっているため, 記録の時間の単位は10μSである. 
        tmp(:,1) = (tmp(:,1) - tmp(1,1))/10^5;
        time = tmp(:,1);
        capa = tmp(:,2);
        timeArrayLength(i) = length(time);
        capaArrayLength(i) = length(capa);
        average(i) = mean(capa);
        minimum(i) = min(capa);
        maximum(i) = max(capa);
        TimeTabledDataCell{i}= timetable(seconds(time), capa); %Timetableはdurationでないといけない.
        TimeTabledDataCell{i} = rmoutliers(TimeTabledDataCell{i}, 'ThresholdFactor',10); % エラーデータ(外れ値)を削除. これ本当に10で良いのか
        TimeTabledDataCell{i} = retime(TimeTabledDataCell{i},'regular','linear','SampleRate',measuredFreq); %おかしなデータは線形内挿.
    end
    representative = table(transpose(conditions), timeArrayLength, capaArrayLength,  maximum, minimum, average);
end

