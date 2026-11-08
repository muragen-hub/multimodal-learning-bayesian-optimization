function processedData = correctWithCapacitanceBase(rawData, rawAllDataBeforeFormat)
%CORRECTWITHCAPACITANCEBASE ボイド率計の樹脂の特性なのか, 実験を進めるにつれて基準値が変化してしまうことへの対応のためのコード
% 用いる基準値のデータ名は,気相100, 液相100でそれぞれ　G30_before_L1.5G1, L100_before_L1.5G1 とする. (例. 条件の部分は適宜変更する)
% 基準値の測定をG30L0で30秒, G0L100で30秒ずつ, 本測定の前に行い, その値を用いて上下を決定し, それに合うように, 次の処理を行う
%1. G30L0の測定値の平均を求め, その値を全データから引く(下限値を固定する. )
%2. G30L0とG0L100のそれぞれの平均値の差分を求め, その差分がに掛けると1*10^(-13)になるような数Xを求める.
%3. 求めた数Xを全データに掛ける.
% [MEMO] 気相条件の数は全液相条件に対して等しいものと仮定する.
arguments
    rawData RawData
    rawAllDataBeforeFormat RawAllDataBeforeFormat
end
if ~rawData.isNeedCorrect
    processedData = rawData; % もし補正がいらないとあればそのまま返す.
    return;
end

rawDataCreator = RawDataCreator();

conditionsLength = length(rawData.conditions);
processedData_capa = cell(1, conditionsLength);

for i = 1:conditionsLength
    % 基準記録の探し方は resolveCapacitanceCalibration.m を参照 (代わりの記録 L0G30, L1G0 も使う)
    if i==1 || rawData.correctConditions(i-1) ~= rawData.correctConditions(i)
        [gasAverageValue, liquidAverageValue, isCalibrated] = resolveCapacitanceCalibration(string(rawData.date), string(rawData.correctConditions(i)));
    end

    % ボイド率 = (液相100% - C) / (液相100% - 気相100%)  → 気相100%で1, 液相100%で0
    % 基準値が無い場合は補正せずそのまま通す
    if isCalibrated
        processedData_capa{i} = (liquidAverageValue - rawData.capacitanceCell{i}) / (liquidAverageValue - gasAverageValue);
    else
        processedData_capa{i} = rawData.capacitanceCell{i};
    end
end
processedData = rawDataCreator.createFromArray(rawData.date,rawData.measuredFreq,rawData.conditions,rawData.labels,rawData.isNeedCorrect,rawData.correctConditions,rawData.timeCell,rawData.timeCell_second,processedData_capa,rawData.labelCell,rawData.liquidFlowRate,rawData.gasFlowRate);
end

