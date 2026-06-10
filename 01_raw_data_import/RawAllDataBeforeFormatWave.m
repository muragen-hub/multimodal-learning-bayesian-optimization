classdef RawAllDataBeforeFormatWave
    % RawAllDataBeforeFormatWave: 学習とテストに使いたい全てのRawDataWaveを束ねるクラス.
    % VFとPrのRawDataWaveを統合し、前処理の引数となる.
    
    properties (SetAccess = immutable)
        mainTable           % VFとPrデータをまとめたテーブル (RawDataWaveインスタンスごとに1行)
        flatTable           % 条件・サンプルごとに展開したテーブル (条件/波形ごとに1行)
        condition           % 条件名リスト (例: L3G20, L1G1 など)
        flowRegimeList      % 流動様式ラベルのリスト (例: Slug, Bubbly など)
    end
    properties (Constant)
        savePathHeader = PictureSavePath.path; % 適切なパスに修正
    end
    
    methods (Access = public)
        function obj = RawAllDataBeforeFormatWave(rawDataWaveArray)
            arguments
                % 入力は RawDataWave の配列 ([trainVF, trainPr, testVF, testPr] など)
                rawDataWaveArray (1,:) RawDataWave 
            end
            
            rawDataArrayLength = length(rawDataWaveArray);
            
            % RawDataWaveは単一の条件を保持しているため、conditionsは各インスタンスから取得
            % 条件名のリストをまず取得（RawDataWaveは conditions{1} に条件名を持つ）
            conditionList = arrayfun(@(x) x.conditions{1}, rawDataWaveArray, 'UniformOutput', false);
            flowRegimeList = arrayfun(@(x) x.FlowRegimeLabel, rawDataWaveArray, 'UniformOutput', false);
            
            obj.condition = unique(string(conditionList));
            obj.flowRegimeList = unique(string(flowRegimeList));
            
            %% --- mainTable の初期化と格納 (RawDataWaveインスタンスごとに1行) ---
            % データを統合して格納
            tmpSize = [rawDataArrayLength, 8];
            varTypes = ["string" "string" "categorical" "cell" "cell" "cell" "cell" "cell"];
            varNames = ["date" "waveType" "flowRegimeLabel" "time_second" "capacitance" "differentialPressure" "liquidFlowRate" "gasFlowRate"];
            obj.mainTable = table('Size', tmpSize, 'VariableTypes', varTypes, 'VariableNames', varNames);
            
            for i = 1:rawDataArrayLength
                rawWave = rawDataWaveArray(i);
                
                % RawDataWaveからデータを取り出す (すべて単一要素のセル配列から取り出す)
                time_second = rawWave.timeCell_second{1};
                liquidFlowRate = rawWave.liquidFlowRate{1};
                gasFlowRate = rawWave.gasFlowRate{1};
                
                % WaveDataCellから波形データを取り出す
                waveData = rawWave.WaveDataCell{1};
                
                % 差圧と静電容量のデータを RawAllDataBeforeFormatWave のプロパティ用に分離/統合
                if strcmp(rawWave.WaveType, "VF")
                    capaData = waveData;
                    dpData = nan(size(waveData)); % Prデータは含まれていない
                elseif strcmp(rawWave.WaveType, "Pr")
                    dpData = waveData;
                    capaData = nan(size(waveData)); % VFデータは含まれていない
                else
                    capaData = nan(size(waveData));
                    dpData = nan(size(waveData));
                end
                
                % mainTableに格納 (RawDataWaveが単一条件なので、すべてのデータは単一セル配列でラップする)
                obj.mainTable(i,:) = {rawWave.date, ...
                                      rawWave.WaveType, ...
                                      categorical(rawWave.FlowRegimeLabel), ...
                                      {time_second}, ... % セル配列でラップ
                                      {capaData}, ... % セル配列でラップ
                                      {dpData}, ... % セル配列でラップ
                                      {liquidFlowRate}, ... % セル配列でラップ
                                      {gasFlowRate}}; % セル配列でラップ
            end
            
            %% --- flatTable の初期化と格納 (RawDataWaveインスタンスごとに1行、mainTableと同じ構造) ---
            % RawDataWaveは既に「条件/波形ごと」に分かれているため、mainTableと同じ構造になる
            % 命名規則を合わせるため flatTable も定義するが、内容は mainTable とほぼ同じになる。
            
            % flatTable の変数名と型を定義
            varTypes_flat = ["string" "string" "categorical" "cell" "cell" "cell" "cell" "cell"];
            varNames_flat = ["date" "waveType" "flowRegimeLabel" "time_second" "capacitance" "differentialPressure" "liquidFlowRate" "gasFlowRate"];
            
            % mainTableの内容をflatTableにコピーし、型の調整（ここでは既に適切）
            obj.flatTable = table('Size', tmpSize, 'VariableTypes', varTypes_flat, 'VariableNames', varNames_flat);
            
            for i = 1:rawDataArrayLength
                 rawWave = rawDataWaveArray(i);
                 
                 % RawDataWaveの構造では、timeCell{1}, capacitanceCell{1} などが既に単一のデータベクトル
                 % flatTableの目的（1行＝1条件データ）は RawDataWave の構造自体で達成されている。
                 obj.flatTable(i,:) = {rawWave.date, ...
                                       rawWave.WaveType, ...
                                       categorical(rawWave.FlowRegimeLabel), ...
                                       {rawWave.timeCell_second{1}}, ... % ★ 修正: {} を追加
                                       {rawWave.capacitanceCell{1}}, ... % ★ 修正: {} を追加
                                       {dpData}, ...                     % ★ 修正: {} を追加
                                       {rawWave.liquidFlowRate{1}}, ...  % ★ 修正: {} を追加
                                       {rawWave.gasFlowRate{1}}};        % ★ 修正: {} を追加
            end
            
        end
        
        %% --- 可視化関数 ---
        % (ここでは元の RawAllDataBeforeFormat の viewALLData の実装は省略します。
        %  新しいデータ構造に合わせてこの関数を修正する必要があります。)
        % function [] = viewALLData(obj, saveFolderName, ylim) ... end
    end
end