function [] = outputAllWaveAndMeasuredFreqConstCheck(src, conditions,folderName)
%OUTPUTALLWAVEANDMEASUREDFREQCONSTCHECK 取得したx秒の全ての波形の表示及び測定周波数が一定でとれているのかどうかの表示を行う.
% 横軸にデータ点数, 縦軸に前のデータからの間隔をプロットする.
% src: データの存在する場所
% conditions: 条件, 例によってstring配列
% folderName: 保存場所

dirName = append("pictures/",folderName);
if not(exist( dirName ,'dir'))
    mkdir( dirName )
end

%パスの作成. data以下に適切に実験データが配置されていることを確認. (gitignoreによりcloneしてきたままではdata以下には何も入っていない)
conditionsLength = length(conditions);
sources = append(src,"/", conditions,"/ALLDATA.csv");

rawdata_time = cell(1, conditionsLength);
rawdata_capa = cell(1, conditionsLength);
%データの形式として, ALLDATAの１列目が時間で２列目が静電容量
for i = 1:conditionsLength
    tmp= readmatrix(sources(i));
    %最初の数プロっトはCメータの関係上うまく取れていない可能性があるので除去. とりあえず50プロットほど除去しておくが
    %ここでは目的は全てのプロットの表示であるため, 最初から含める.
    tmp(:,1) = (tmp(:,1) - tmp(1,1))/10^5; % 0.02秒が2000となっているため, 記録の時間の単位は10μSである.
    rawdata_time{i} = tmp(1: end,1);
    rawdata_capa{i} = tmp(1: end,2);
end

min = transpose(cellfun(@min, rawdata_capa));
idx = transpose(min<0);
for i =1:conditionsLength
    if idx(i) == 1
        rawdata_capa{i} = rmoutliers(rawdata_capa{i}, 'ThresholdFactor',10); % エラーデータ(外れ値)を削除. これ本当に10で良いのか.
        rawdata_time{i} = rmoutliers(rawdata_time{i},'ThresholdFactor',10);
    end
end

%代表値の取り出し
average = transpose(cellfun(@mean, rawdata_capa));
min = transpose(cellfun(@min, rawdata_capa));
max = transpose(cellfun(@max, rawdata_capa));

for i = 1:length(conditions)
    figure;
    hold on;
    plot(rawdata_time{i},rawdata_capa{i})%,'.','MarkerSize',4);
    yline(min(i),'b-',{append("min",string(min(i)))});
    yline(max(i),'r-',{append("max",string(max(i)))});
    yline(average(i),'k-',{append("average",string(average(i)))});
    hold off;
    ylim([2*(10.^(-13)) 4.5*(10.^(-13))]);
    ylabel("静電容量 F")
    xlabel("時間 s")
    legend(["データ本体" "最小値" "最大値" "平均値"]);
    title(conditions(i),'Units', 'normalized', 'Position', [0.5, -0.135, 0])
    saveas(gcf, append( dirName , conditions(i),"AllWave.fig"))
end

for i = 1:length(conditions)
    figure
    plot(diff(rawdata_time{i}))
    ylabel("前の測定時間との時間の差分 s")
    xlabel("測定番号")
    ylim([0 0.1]);
    title(conditions(i),'Units', 'normalized', 'Position', [0.5, -0.135, 0])
    saveas(gcf, append( dirName , conditions(i),"TimeDelta(For FreqCheck).fig"))
end

end

