function processedData = splineIntervalUniformer(rawData, rawAllDataBeforeFormat)
%INTERVAL Cメータとトリガがおかしい関係上, データの取得間隔がぶれるので, それを調整するための関数.
arguments
    rawData RawData
    rawAllDataBeforeFormat RawAllDataBeforeFormat
end
conditionsLength = length(rawData.conditions);
TimeTabledDataCell = cell(1, conditionsLength);
processedCapa = cell(1,conditionsLength);
processedTime = cell(1, conditionsLength);
if(~isempty(rawData.liquidFlowRate))
    processedLiquidFlowRate = cell(1,conditionsLength);
    processedGasFlowRate = cell(1,conditionsLength);
end
for i = 1:conditionsLength
    if(~isempty(rawData.liquidFlowRate)) % MATLABにはnullabaleが無く, 型ガードもないためemptyチェックが結構危ういが, 既存コードとの互換性のために致しかたなし.
        TimeTabledDataCell{i}= timetable(seconds(rawData.timeCell_second{i}), rawData.capacitanceCell{i},rawData.liquidFlowRate{i}, rawData.gasFlowRate{i},'VariableNames',{'Capacitance', 'LiquidFlowRate', 'GasFlowRate'});
        TimeTabledDataCell{i} = retime(TimeTabledDataCell{i},'regular','spline','SampleRate',rawData.measuredFreq); %おかしなデータは線形内挿.
        processedTime{i} = TimeTabledDataCell{i}.Time;
        processedCapa{i} = TimeTabledDataCell{i}.Capacitance;
        processedLiquidFlowRate{i} = TimeTabledDataCell{i}.LiquidFlowRate;
        processedGasFlowRate{i} = TimeTabledDataCell{i}.GasFlowRate;
    else
        TimeTabledDataCell{i}= timetable(seconds(rawData.timeCell_second{i}), rawData.capacitanceCell{i},'VariableNames',{'Capacitance'});
        TimeTabledDataCell{i} = retime(TimeTabledDataCell{i},'regular','spline','SampleRate',rawData.measuredFreq); %おかしなデータは線形内挿.
        processedTime{i} = TimeTabledDataCell{i}.Time;
        processedCapa{i} = TimeTabledDataCell{i}.Capacitance;
    end
end
creator = RawDataCreator();
if(~isempty(rawData.liquidFlowRate))
    processedData = creator.createFromArray(rawData.date,rawData.measuredFreq,rawData.conditions,rawData.labels,rawData.isNeedCorrect,rawData.correctConditions,processedTime,processedTime,processedCapa,rawData.labelCell,processedLiquidFlowRate,processedGasFlowRate);
else
    processedData = creator.createFromArray(rawData.date,rawData.measuredFreq,rawData.conditions,rawData.labels,rawData.isNeedCorrect,rawData.correctConditions,processedTime,processedTime,processedCapa,rawData.labelCell,rawData.liquidFlowRate,rawData.gasFlowRate);
end
end

