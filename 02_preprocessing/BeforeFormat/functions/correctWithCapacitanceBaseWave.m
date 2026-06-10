function processedDataWave = correctWithCapacitanceBaseWave(rawDataWave, rawAllDataBeforeFormatWave)
% CORRECTWITHCAPACITANCEBASEWAVE: VF基準値のドリフトを補正する関数。Pr波形には適用しない。
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
    
    % RawDataWaveは単一条件 (i=1 のみ)
    correctCondition = rawDataWave.correctConditions{1};
    
    gasAverageValue = 0; % 初期値
    liquidAverageValue = 1; % 初期値
    calibrationDividingNum = 1; % 初期値
    
    % --- 気相100% (下限値) の処理 ---
    % DataPath.path, CorrectConditions.LiquidPureFlowPrefix は外部定義済みと仮定
    gasCalibrationSource = append(DataPath.path, rawDataWave.date, "/", CorrectConditions.LiquidPureFlowPrefix, correctCondition, "/ALLDATA.csv");
    
    if exist(gasCalibrationSource, 'file') ~= 2
        warning('気相100%%の基準データ (%s) が見つかりません。静電容量補正をスキップします。', gasCalibrationSource);
    else
        % ファイルが見つかった場合の通常処理
        tmp = readmatrix(gasCalibrationSource);
        gasCalibrationRawdata_capa = tmp(1: end,2);
        gasAverageValue = mean(rmoutliers(gasCalibrationRawdata_capa, 'ThresholdFactor',10));
    end
    
    % --- 液相100% (上限値) の処理 ---
    liquidCalibrationSource = append(DataPath.path, rawDataWave.date, "/", correctCondition, CorrectConditions.gasPreFlowSuffix, "/ALLDATA.csv");
    
    if exist(liquidCalibrationSource, 'file') ~= 2 || gasAverageValue == 0 
        % 液相100%が見つからない、またはすでに気相処理でスキップフラグが立っている場合
        warning('液相100%%の基準データ (%s) が見つからないか、気相基準値が0です。静電容量補正をスキップします。', liquidCalibrationSource);
        
        % スキップ値を適用 (gasAverageValue=0, liquidAverageValue=1, calibrationDividingNum=1のまま)
    else
        % ファイルが見つかった場合の通常処理
        tmp = readmatrix(liquidCalibrationSource);
        liquidCalibrationRawdata_capa = tmp(1: end,2);
        liquidAverageValue = mean(rmoutliers(liquidCalibrationRawdata_capa, 'ThresholdFactor',10));
        
        % スケール調整係数の計算
        gasLiquidAverageDiff = liquidAverageValue - gasAverageValue;
        
        % 差がゼロに近い場合は補正を行わない
        if abs(gasLiquidAverageDiff) < 1e-15
            warning('基準値の差分がゼロに近いため、スケーリング補正をスキップします。');
            calibrationDividingNum = 1;
        else
            calibrationDividingNum = 1/gasLiquidAverageDiff;
        end
    end
    
    % --- 2. 補正の適用 ---
    
    % RawDataWaveのWaveDataCell（VF波形）に補正を適用
    processedWaveData = (rawDataWave.WaveDataCell{1} - gasAverageValue) * calibrationDividingNum;
    
    % RawDataのCapacitanceCellにも補正を適用
    % ※ WaveDataCellとCapacitanceCellはVFデータの場合、元々同じ内容を持つはずだが、
    %    互換性のため両方を処理する（RawDataのCapaCellも更新しておく）
    processedCapaForRawData = (rawDataWave.capacitanceCell{1} - gasAverageValue) * calibrationDividingNum;
    
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