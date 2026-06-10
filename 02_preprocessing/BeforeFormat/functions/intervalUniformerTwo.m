function processedData = intervalUniformerTwo(rawDataTwo, rawAllDataBeforeFormatTwo)
arguments
    rawDataTwo RawDataTwo
    rawAllDataBeforeFormatTwo RawAllDataBeforeFormatTwo
end

conditionsLength = length(rawDataTwo.conditions);

% --- 出力セル配列初期化 ---
processedCapa = cell(1, conditionsLength);
processedTime = cell(1, conditionsLength);
processedDifferentialPressure = cell(1, conditionsLength);

processedLiquidFlowRate = rawDataTwo.liquidFlowRate;
processedGasFlowRate    = rawDataTwo.gasFlowRate;
if ~isempty(rawDataTwo.liquidFlowRate)
    processedLiquidFlowRate = cell(1, conditionsLength);
    processedGasFlowRate    = cell(1, conditionsLength);
end

% --- 条件ごとに処理 ---
for i = 1:conditionsLength
    % 処理開始メッセージを削除/コメントアウト
    % fprintf("=== 条件 %d 処理開始 ===\n", i); 
    
    % --- データ取得 ---
    capData  = rawDataTwo.capacitanceCell{i};
    diffData = rawDataTwo.differentialPressure{i};
    
    % --- 型チェック ---
    assert(isnumeric(capData), 'Capacitance must be numeric');
    assert(isnumeric(diffData), 'DifferentialPressure must be numeric');
    
    nCap  = size(capData, 2);
    nDiff = size(diffData, 2);
    
    % --- 変数名生成 ---
    capVars  = strcat("Capacitance", string(1:nCap));
    diffVars = strcat("DifferentialPressure", string(1:nDiff));
    vars = [capVars, diffVars];
    
    data = [capData, diffData];
    
    % --- 流量データがある場合 ---
    if ~isempty(rawDataTwo.liquidFlowRate)
        liquidData = rawDataTwo.liquidFlowRate{i};
        gasData    = rawDataTwo.gasFlowRate{i};
        
        assert(isnumeric(liquidData), 'LiquidFlowRate must be numeric');
        assert(isnumeric(gasData), 'GasFlowRate must be numeric');
        
        nLiquid = size(liquidData,2);
        nGas    = size(gasData,2);
        
        liquidVars = strcat("LiquidFlowRate", string(1:nLiquid));
        gasVars    = strcat("GasFlowRate", string(1:nGas));
        
        vars = [vars, liquidVars, gasVars];
        data = [data, liquidData, gasData];
    end
    
    % --- 行数チェック ---
    assert(size(data,1) == length(rawDataTwo.timeCell_second{i}), ...
        'Time vector length must match data rows');
    
    % --- デバッグ情報 (初期) を削除/コメントアウト
    % fprintf("data 行=%d, 列=%d, VariableNames=%d\n", size(data,1), size(data,2), length(vars)); 
    
    % --- timetable作成 (最終安全策) ---
    
    % 1. 時間ベクトルの形状保証: N x 1 の列ベクトル
    time_raw = rawDataTwo.timeCell_second{i};
    time_vector = seconds(time_raw(:)); 
    
    % 2. 変数名 (vars_safe) の最終準備: 1 x M の行セル配列
    vars_safe = cellstr(vars);
    vars_safe = vars_safe(:).'; 
    N_vars = length(vars_safe);
    
    % 3. データ行列の形状保証: N x M の行列
    data_final = reshape(data, [], N_vars); 
    
    % 4. デバッグ情報表示 (最終確認) を削除/コメントアウト
    % fprintf("vars_safe 内容: %s\n", strjoin(vars_safe, ', '));
    % fprintf("time_vector size: %s, data_final size: %s\n", ...
    %     mat2str(size(time_vector)), mat2str(size(data_final)));

    % 5. table経由でtimetable生成 
    
    % (A) data_final (N x M 行列) を table に変換
    T = array2table(data_final, 'VariableNames', vars_safe);
    
    % (B) table の RowTimes に time_vector (N x 1 列ベクトル) を設定
    T.RowTimes = time_vector; 
    
    % (C) table を timetable に変換
    TT = table2timetable(T); 
    
    % --- リサンプリング ---
    TT = retime(TT, 'regular', 'linear', 'SampleRate', rawDataTwo.measuredFreq);
    
    % --- 出力格納 ---
    processedTime{i} = TT.RowTimes; 
    processedCapa{i} = TT{:, capVars};
    processedDifferentialPressure{i} = TT{:, diffVars};
    
    if ~isempty(rawDataTwo.liquidFlowRate)
        processedLiquidFlowRate{i} = TT{:, liquidVars};
        processedGasFlowRate{i}    = TT{:, gasVars};
    end
    
    % 処理完了メッセージを削除/コメントアウト
    % fprintf("=== 条件 %d 処理完了 ===\n\n", i); 
end

% --- RawDataTwo の再生成 ---
creator = RawDataCreatorTwo();
processedData = creator.createFromArray(...
    rawDataTwo.date, rawDataTwo.measuredFreq, rawDataTwo.conditions, rawDataTwo.labels, ...
    rawDataTwo.isNeedCorrect, rawDataTwo.correctConditions, ...
    processedTime, processedTime, processedCapa, rawDataTwo.flowRegimeCell, ...
    rawDataTwo.featureCell, rawDataTwo.machineLearningCell, rawDataTwo.labelCell, ...
    processedLiquidFlowRate, processedGasFlowRate, processedDifferentialPressure);

end