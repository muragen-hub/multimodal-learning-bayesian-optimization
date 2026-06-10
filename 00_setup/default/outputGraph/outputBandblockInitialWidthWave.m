function [] = outputBandblockInitialWidthWave(conditions,cellData,folderName,givenTitle)
%OUTPUTBANDBLOCKWAVE % 各流量条件について最初のdataWidth分の波形の表示を行う.
% conditions: 流量条件のいつものstring配列
% cellData: conditionsと同じ順序でセルにデータが詰まっている, 流量条件数だけの長さのあるセル配列.(12条件なら12セル, 前からL1.5G1 L1.5G25...など)
% folderName: 画像専用のpicturesフォルダの中での保存先のフォルダー, 最後の/を忘れないで.(面倒なので引数の検証とか省いてます.)
dirName = append("pictures/",folderName);
if not(exist( dirName ,'dir'))
    mkdir( dirName )
end

for i=1:length(conditions)
    figure
    graphedData = cellData{i}(200,:);
    plot(graphedData,'.','MarkerSize',2.5)
    meanValue = mean(graphedData);
    minValue = min(graphedData);
    maxValue = max(graphedData);
    yline(minValue,'b-',{append("min",string(minValue))});
    yline(maxValue,'r-',{append("max",string(maxValue))});
    yline(meanValue,'k-',{append("average",string(meanValue))});
    ylim([2*(10.^(-13)) 4.5*(10.^(-13))]);
    ylabel("静電容量 F")
    xlabel("測定番号")
    legend(["データ本体" "最小値" "最大値" "平均値"]);
    title(append(givenTitle, conditions(i)),'Units', 'normalized', 'Position', [0.5, -0.135, 0])
    saveas(gcf, append( dirName, conditions(i),"initialWidth.fig"))
end
end

