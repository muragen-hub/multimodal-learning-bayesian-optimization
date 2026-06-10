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
    
    % ループ内で使用する変数
    gasAverageValue = 0; % 初期値設定
    liquidAverageValue = 1; % 初期値設定
    calibrationDividingNum = 1; % 初期値設定
    
    for i = 1:conditionsLength
        % 補正条件が切り替わった場合、または最初の条件の場合に基準値を再計算
        if i==1 || rawDataTwo.correctConditions(i-1) ~= rawDataTwo.correctConditions(i)
            
            % --- 気相100% (下限値) の処理 ---
            gasCalibrationSource = append(DataPath.path,rawDataTwo.date,"/",CorrectConditions.LiquidPureFlowPrefix, rawDataTwo.correctConditions(i),"/ALLDATA.csv");
            
            % 💡 修正箇所: ファイル存在チェック
            if exist(gasCalibrationSource, 'file') ~= 2
                warning('気相100%%の基準データ (%s) が見つかりません。この条件の静電容量補正をスキップします。', gasCalibrationSource);
                
                % 補正をスキップするための値を設定: (data - 0) * 1 となる
                gasAverageValue = 0; 
                liquidAverageValue = 1; 
                calibrationDividingNum = 1; 
                
                % このスキップ処理が発動した場合、液相100%の読み込みもスキップ
                
            else
            % ファイルが見つかった場合の通常処理
            tmp= readmatrix(gasCalibrationSource);
            gasCalibrationRawdata_capa{1} = tmp(1: end,2);
            gasAverageValue = mean(rmoutliers(gasCalibrationRawdata_capa{1}, 'ThresholdFactor',10));
            
            
            liquidCalibrationSource = append(DataPath.path,rawDataTwo.date, "/",rawDataTwo.correctConditions(i) ,CorrectConditions.gasPreFlowSuffix,"/ALLDATA.csv");
            
            % 💡 修正箇所: 液相100%ファイルの存在チェックとスキップ処理
            if exist(liquidCalibrationSource, 'file') ~= 2
                % 液相100%の基準データが見つからない場合
                warning('液相100%%の基準データ (%s) が見つかりません。この条件の静電容量補正をスキップします。', liquidCalibrationSource);
                
                % 補正をスキップするための値を設定: (data - 0) * 1 となる
                gasAverageValue = 0;
                liquidAverageValue = 1;
                calibrationDividingNum = 1;
                
            else
                % ファイルが見つかった場合の通常処理
                tmp= readmatrix(liquidCalibrationSource);
                liquidCalibrationRawdata_capa{1} = tmp(1: end,2);
                liquidAverageValue = mean(rmoutliers(liquidCalibrationRawdata_capa{1}, 'ThresholdFactor',10));
                
                % スケール調整係数の計算
                gasLiquidAverageDiff = liquidAverageValue - gasAverageValue;
                calibrationDividingNum = 1/gasLiquidAverageDiff;
            end
        end
    end

    % 静電容量の補正を適用 (スキップされた場合も、設定値 0 と 1 によりデータがそのまま通過)
    processedData_capa{i} = (rawDataTwo.capacitanceCell{i} - gasAverageValue)*calibrationDividingNum;
end

% 変更点2: createFromArray の最後に差圧データを渡す
processedData = rawDataCreatorTwo.createFromArray(rawDataTwo.date,rawDataTwo.measuredFreq,rawDataTwo.conditions,rawDataTwo.labels,rawDataTwo.isNeedCorrect,rawDataTwo.correctConditions, ...
    rawDataTwo.timeCell,rawDataTwo.timeCell_second,processedData_capa, rawDataTwo.flowRegimeCell, rawDataTwo.featureCell, rawDataTwo.machineLearningCell, rawDataTwo.labelCell, ...
    rawDataTwo.liquidFlowRate, rawDataTwo.gasFlowRate, processedData_diffPressure); 

end