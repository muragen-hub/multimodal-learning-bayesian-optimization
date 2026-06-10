function processedData = earlyStandardize(rawData, rawAllDataBeforeFormat)
%STANDARDIZE 訓練前の標準化を行う関数
%rawAllDataを使う関係上, 関数を置く順番に注意. 
%なんなら, preprocessorを二段階でかませる必要がある. 
arguments
    rawData RawData
    rawAllDataBeforeFormat RawAllDataBeforeFormat
end
% データの標準化
% 平均が0、分散が1になるようにデータを標準化する。予測時も学習時と同様のパラメータを用いて標準化する必要がある。

allCapa = [];
%flatTableのcapacitanceを全て足す. 
flatTableHeight = height(rawAllDataBeforeFormat.flatTable);
for j = 1:flatTableHeight
    allCapa = [allCapa; rawAllDataBeforeFormat.flatTable(j,:).capacitance{1}]; %#ok
end

mu = mean(allCapa,'all');
sig = std(allCapa,0,'all');

conditionLength = length(rawData.conditions);
processedCapa = cell(1,length(conditionLength));

for j=1:conditionLength
    processedCapa{j} = (rawData.capacitanceCell{j} -mu) ./sig;
end

rawDataCreator = RawDataCreator();
processedData = rawDataCreator.createFromArray(rawData.date,rawData.measuredFreq,rawData.conditions,rawData.labels,rawData.isNeedCorrect,rawData.correctConditions,rawData.timeCell,rawData.timeCell_second,processedCapa,rawData.labelCell,rawData.liquidFlowRate,rawData.gasFlowRate);
clear allCapa 
end

