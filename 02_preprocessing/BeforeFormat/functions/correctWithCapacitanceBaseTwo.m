function processedData = correctWithCapacitanceBaseTwo(rawDataTwo, rawAllDataBeforeFormatTwo)
%CORRECTWITHCAPACITANCEBASE ボイド率計の基準値ドリフトに対応するための補正コード。
% 差圧データは本関数では処理せず、そのまま通過させる。

%CORRECTWITHCAPACITANCEBASE ボイド率計の樹脂の特性なのか, 実験を進めるにつれて基準値が変化してしまうことへの対応のためのコード
% 用いる基準値のデータ名は,気相100, 液相100でそれぞれ　G30_before_L1.5G1, L100_before_L1.5G1 とする. (例. 条件の部分は適宜変更する)
% 基準値の測定をG30L0で30秒, G0L100で30秒ずつ, 本測定の前に行い, その値を用いて上下を決定し, それに合うように, 次の処理を行う
%1. G30L0の測定値の平均を求め, その値を全データから引く(下限値を固定する. )
%2. G30L0とG0L100のそれぞれの平均値の差分を求め, その差分がに掛けると1*10^(-13)になるような数Xを求める.
%3. 求めた数Xを全データに掛ける.
% [MEMO] 気相条件の数は全液相条件に対して等しいものと仮定する.

    arguments
        rawDataTwo RawDataTwo
        rawAllDataBeforeFormatTwo RawAllDataBeforeFormatTwo
    end
    
    if ~rawDataTwo.isNeedCorrect
        processedData = rawDataTwo; % もし補正がいらないとあればそのまま返す。
        return;
    end
    
    rawDataCreatorTwo = RawDataCreatorTwo();
    
    conditionsLength = length(rawDataTwo.conditions);
    processedData_capa = cell(1, conditionsLength);
    
    % 差圧データをそのまま引き継ぐための変数
    processedData_diffPressure = rawDataTwo.differentialPressure;
    
    for i = 1:conditionsLength
        % 補正条件が切り替わった場合、または最初の条件の場合に基準値を再計算
        % 基準記録の探し方は resolveCapacitanceCalibration.m を参照 (代わりの記録 L0G30, L1G0 も使う)
        if i==1 || rawDataTwo.correctConditions(i-1) ~= rawDataTwo.correctConditions(i)
            [gasAverageValue, liquidAverageValue, isCalibrated] = resolveCapacitanceCalibration(string(rawDataTwo.date), string(rawDataTwo.correctConditions(i)));
        end

        % ボイド率 = (液相100% - C) / (液相100% - 気相100%)  → 気相100%で1, 液相100%で0
        % 基準値が無い場合は補正せずそのまま通す
        if isCalibrated
            processedData_capa{i} = (liquidAverageValue - rawDataTwo.capacitanceCell{i}) / (liquidAverageValue - gasAverageValue);
        else
            processedData_capa{i} = rawDataTwo.capacitanceCell{i};
        end
    end

% 変更点2: createFromArray の最後に差圧データを渡す
processedData = rawDataCreatorTwo.createFromArray(rawDataTwo.date,rawDataTwo.measuredFreq,rawDataTwo.conditions,rawDataTwo.labels,rawDataTwo.isNeedCorrect,rawDataTwo.correctConditions, ...
    rawDataTwo.timeCell,rawDataTwo.timeCell_second,processedData_capa, rawDataTwo.flowRegimeCell, rawDataTwo.featureCell, rawDataTwo.machineLearningCell, rawDataTwo.labelCell, ...
    rawDataTwo.liquidFlowRate, rawDataTwo.gasFlowRate, processedData_diffPressure); 

end