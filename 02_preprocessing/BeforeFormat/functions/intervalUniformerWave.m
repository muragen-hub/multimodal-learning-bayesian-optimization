function processedDataWave = intervalUniformerWave(rawDataWave, rawAllDataBeforeFormatWave)
% INTERVALUNIFORMERWAVE Cメータとトリガのずれを調整するための関数 (RawDataWave用)、線形補間あり！
arguments
    rawDataWave RawDataWave 
    rawAllDataBeforeFormatWave RawAllDataBeforeFormatWave
end
% RawDataWaveが配列で渡された場合の対策として、(1) を付加してスカラーアクセスを保証
% RawDataWaveは単一条件なので、セル配列から {1} を取り出す
time_seconds = rawDataWave(1).timeCell_second{1}; 
waveType = rawDataWave(1).WaveType;
measuredFreq = rawDataWave(1).measuredFreq;
% 処理対象となる波形データ (VFまたはPr)
waveData = rawDataWave(1).WaveDataCell{1};
% 流量データ (データ構造維持のため取得はするが、リサンプリングには使わない)
liquidFlowRate = rawDataWave(1).liquidFlowRate{1};
gasFlowRate = rawDataWave(1).gasFlowRate{1};

% --- timetable作成とリサンプリング (波形データのみを対象とする) ---
data = waveData;
varNames = {['WaveData_', char(waveType)]}; % 例: 'WaveData_VF'

% ★ 修正ポイント: 流量データの連結処理を完全に削除/コメントアウト ★
% if hasFlowRate
%     data = [data, liquidFlowRate, gasFlowRate];
%     varNames = [varNames, 'LiquidFlowRate', 'GasFlowRate'];
% end

% timetable作成
time_vector = seconds(time_seconds(:)); 
T = array2table(data, 'VariableNames', cellstr(varNames));
T.RowTimes = time_vector; 
TT = table2timetable(T); 

% リサンプリング (おかしなデータは線形内挿)
TT = retime(TT, 'regular', 'linear', 'SampleRate', measuredFreq);

% --- 処理済みデータの取得 ---
processedTimeSeconds = TT.RowTimes; % duration型
processedWaveData = TT{:, 1}; % 最初の列 (WaveData_VF or WaveData_Pr)

% RawDataの互換性のため、元のCapaCellデータを維持（またはPrならNaN）
processedCapaForRawData = rawDataWave(1).capacitanceCell{1}; 

% ★ 修正ポイント: 流量データは元の値をそのまま返す（RawDataWaveの構造維持のため） ★
processedLiquidFlowRate = liquidFlowRate;
processedGasFlowRate    = gasFlowRate;

% intervalUniformerWave (行 50付近)

% --- RawDataWaveの再生成 ---
creator = RawDataCreatorWave();
processedDataWave = creator.createFromArray(...
    rawDataWave(1).WaveType, ...
    rawDataWave(1).date, rawDataWave(1).measuredFreq, ...
    {rawDataWave(1).conditions}, ...         % ★ 修正: stringを { } で包む
    {rawDataWave(1).labels}, ...             % ★ 修正: stringを { } で包む
    rawDataWave(1).isNeedCorrect, ...
    {rawDataWave(1).correctConditions}, ...  % ★ 修正: stringを { } で包む
    {processedTimeSeconds}, {seconds(processedTimeSeconds)}, ...
    {processedCapaForRawData}, rawDataWave(1).labelCell, ...
    {processedLiquidFlowRate}, {processedGasFlowRate}, ...
    {processedWaveData}, rawDataWave(1).FlowRegimeLabel);
    
end