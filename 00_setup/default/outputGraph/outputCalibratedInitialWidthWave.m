function [] = outputCalibratedInitialWidthWave(conditions,cellData,folderName,givenTitle)
%OUTPUTCARIBRATEDINITIALWAVE この関数の概要をここに記述
%[TODO] upperとlowerを指定できるようにするべき. もう一つのinitialWave表示用の関数と統合するべき.
% 各流量条件について最初ではなく, 50stride後のdataWidth分の波形の表示を行う.
% これは最初の部分はフィルターの影響によりおかしくなっているためである.
% conditions: 流量条件のいつものstring配列
% cellData: conditionsと同じ順序でセルにデータが詰まっている, 流量条件数だけの長さのあるセル配列.(12条件なら12セル, 前からL1.5G1 L1.5G25...など)
% folderName: 画像専用のpicturesフォルダの中での保存先のフォルダー, 最後の/を忘れないで.(面倒なので引数の検証とか省いてます.)

dirName = append("pictures/",folderName);
if not(exist( dirName ,'dir'))
    mkdir( dirName )
end

for i=1:length(conditions)
    figure
    plot(cellData{i}(50,:))
    ylim([0 1.5*(10.^(-13))]);
    ylabel("静電容量 F")
    xlabel("測定番号")
    title(append(givenTitle, conditions(i)),'Units', 'normalized', 'Position', [0.5, -0.135, 0])
    saveas(gcf, append( dirName, conditions(i),"initialWidth.fig"))
end
end

