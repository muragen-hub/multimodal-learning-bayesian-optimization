function [] = output1Data(data,label,folderName,givenTitle,range)
% 正規化後のグラフを表示する.
% conditions: 流量条件のいつものstring配列
% cellData: conditionsと同じ順序でセルにデータが詰まっている, 流量条件数だけの長さのあるセル配列.(12条件なら12セル, 前からL1.5G1 L1.5G25...など)
% folderName: 画像専用のpicturesフォルダの中での保存先のフォルダー, 最後の/を忘れないで.(面倒なので引数の検証とか省いてます.)

dirName = append("pictures/",folderName);
if not(exist( dirName ,'dir'))
    mkdir( dirName )
end

condition = label(50);
figure
plot(data{50},'.','MarkerSize',2.5)
meanValue = mean(data{50});
minValue = min(data{50});
maxValue = max(data{50});
yline(minValue,'b-',{append("min",string(minValue))});
yline(maxValue,'r-',{append("max",string(maxValue))});
yline(meanValue,'k-',{append("average",string(meanValue))});
ylim(range);
ylabel("静電容量(標準化) F")
xlabel("測定番号")
legend(["データ本体" "最小値" "最大値" "平均値"]);
title(append(givenTitle,string(condition)),'Units', 'normalized', 'Position', [0.5, -0.135, 0])
saveas(gcf, append(dirName, string(condition),"normal.png"))

for hoge = 50:length(label)
    if (label(hoge-1) == label(hoge))
        continue;
    end
    condition = label(hoge+50);
    figure
    plot(data{hoge+50},'.','MarkerSize',2.5)
    meanValue = mean(data{hoge+50});
    minValue = min(data{hoge+50});
    maxValue = max(data{hoge+50});
    yline(minValue,'b-',{append("min",string(minValue))});
    yline(maxValue,'r-',{append("max",string(maxValue))});
    yline(meanValue,'k-',{append("average",string(meanValue))});
    ylim(range);
    ylabel("静電容量(標準化) F")
    xlabel("測定番号")
    legend(["データ本体" "最小値" "最大値" "平均値"]);
    title(append(givenTitle,string(condition)),'Units', 'normalized', 'Position', [0.5, -0.135, 0])
    saveas(gcf, append(dirName,string(condition),"normal.png"))
end
end
