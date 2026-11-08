function processedDataWave = correctWithCapacitanceBaseWave(rawDataWave, rawAllDataBeforeFormatWave)
% CORRECTWITHCAPACITANCEBASEWAVE: 静電容量を気相100%・液相100%の基準値でボイド率に換算する関数。Pr波形には適用しない。
    arguments
        rawDataWave RawDataWave
        rawAllDataBeforeFormatWave RawAllDataBeforeFormatWave
    end
    
    % --- 0. 補正不要/差圧データの場合のスキップ処理 ---
    
    % 1. 元々補正が不要と指定されていた場合、そのまま返す
    if ~rawDataWave.isNeedCorrect
        processedDataWave = rawDataWave;
        return;
    end
    
    % 2. 差圧データ (Pr) の場合、補正をスキップしてそのまま返す
    if strcmp(rawDataWave.WaveType, "Pr")
        % 差圧補正はここでは行わないため、そのまま返す
        processedDataWave = rawDataWave; 
        return;
    end
    
    % ここから先は WaveType == "VF" で、かつ補正が必要なデータのみを処理する
    
    % --- 1. 基準値の計算 (条件は単一のため、ループは不要) ---
    % 基準記録の探し方は resolveCapacitanceCalibration.m を参照 (代わりの記録 L0G30, L1G0 も使う)
    correctCondition = string(rawDataWave.correctConditions{1});
    [gasAverageValue, liquidAverageValue, isCalibrated] = resolveCapacitanceCalibration(string(rawDataWave.date), correctCondition);

    % --- 2. 補正の適用 ---
    % ボイド率 = (液相100% - C) / (液相100% - 気相100%)  → 気相100%で1, 液相100%で0
    % (以前は (C - 気相100%)/(液相100% - 気相100%) で, 液相の割合(1 - ボイド率)になっていた)
    if isCalibrated
        toVoidFraction = @(c) (liquidAverageValue - c) / (liquidAverageValue - gasAverageValue);
    else
        toVoidFraction = @(c) c; % 基準値が無い場合は補正せずそのまま通す
    end
    processedWaveData = toVoidFraction(rawDataWave.WaveDataCell{1});
    % WaveDataCellとCapacitanceCellはVFデータの場合同じ内容のはずだが, 互換性のため両方を処理する
    processedCapaForRawData = toVoidFraction(rawDataWave.capacitanceCell{1});

    % --- 3. RawDataWaveの再生成 ---
    rawDataCreator = RawDataCreatorWave();

% 引数: WaveType, date, measuredFreq, conditions, labels, isNeedCorrect, correctConditions, ...
    processedDataWave = rawDataCreator.createFromArray(...
    rawDataWave.WaveType, ...
    rawDataWave.date, rawDataWave.measuredFreq, ...
    {rawDataWave.conditions}, ...         % ★ 修正: conditions をセル配列で渡す
    {rawDataWave.labels}, ...             % ★ 修正: labels をセル配列で渡す
    rawDataWave.isNeedCorrect, ...
    {rawDataWave.correctConditions}, ...  % ★ 修正: correctConditions をセル配列で渡す
    rawDataWave.timeCell, rawDataWave.timeCell_second, ... % 時間データは変更なし
    {processedCapaForRawData}, rawDataWave.labelCell, ... % 補正済みCapa (RawData互換用)
    rawDataWave.liquidFlowRate, rawDataWave.gasFlowRate, ... % 流量データは変更なし
    {processedWaveData}, rawDataWave.FlowRegimeLabel); % 補正済みWaveData (判別用)
end