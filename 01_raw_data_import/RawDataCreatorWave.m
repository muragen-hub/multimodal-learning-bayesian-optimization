classdef RawDataCreatorWave
    % RawDataCreatorWave: Excelデータから RawDataWave クラスを作る Factory
    
    properties (Constant)
        sourcePathHeader = DataPath.path;

    end
    
    methods (Access = public)
        function obj = RawDataCreatorWave()
        end

        %% createVF メソッド (静電容量/VF データ生成)
        function createdRawDataWave = createVF(obj, date, measuredFreq, conditions, labels, isNeedCorrect, correctConditions)
            createdRawDataWave = obj.createInternal("VF", date, measuredFreq, conditions, labels, isNeedCorrect, correctConditions);
        end

        %% createPr メソッド (差圧/Pr データ生成)
        function createdRawDataWave = createPr(obj, date, measuredFreq, conditions, labels, isNeedCorrect, correctConditions)
            createdRawDataWave = obj.createInternal("Pr", date, measuredFreq, conditions, labels, isNeedCorrect, correctConditions);
        end
        % RawDataCreatorWave クラス内の methods (Access = public) に追加

        function processedDataWave = createFromArray(obj, waveType, date, measuredFreq, conditions, labels, ...
            isNeedCorrect, correctConditions, timeCell, timeCell_second, capacitanceCell, labelCell, ...
            liquidFlowRate, gasFlowRate, waveDataCell, flowRegimeLabel)
        % createFromArray: 前処理済みデータから RawDataWave インスタンスを生成するヘルパー関数
        
            arguments
                obj RawDataCreatorWave
                waveType string % ★ 追加: 処理された波形のタイプ ('VF' または 'Pr')
                date string
                measuredFreq {mustBePositive}
                conditions (1,:) cell
                labels (1,:) cell
                isNeedCorrect logical
                correctConditions (1,:) cell
                timeCell (1,:) cell
                timeCell_second (1,:) cell
                capacitanceCell (1,:) cell
                labelCell (1,:) cell
                liquidFlowRate (1,:) cell
                gasFlowRate (1,:) cell
                waveDataCell (1,:) cell % 処理後の波形データ ({vector} 形式)
                flowRegimeLabel string
            end
            
            % RawDataWaveのコンストラクタを呼び出す
            % RawDataWaveのコンストラクタ引数順序に厳密に従う必要があります。
            % RawDataWave コンストラクタ引数順序:
            % (WaveType, WaveDataCell, FlowRegimeLabel, date, measuredFreq, condition, label, isNeedCorrect, correctCondition, TimeCell, TimeCell_second, CapacitanceCell, LabelCell, LiquidFlowRate, GasFlowRate)
            
            processedDataWave = RawDataWave(...
                waveType, ...               % WaveType
                waveDataCell, ...           % WaveDataCell
                flowRegimeLabel, ...        % FlowRegimeLabel
                date, measuredFreq, ...
                conditions, labels, isNeedCorrect, correctConditions, ...
                timeCell, timeCell_second, capacitanceCell, labelCell, ...
                liquidFlowRate, gasFlowRate);
        
        end
    end
    
    % RawDataCreatorWave.m の createInternal メソッド (修正案)

    methods (Access = private)
        % 内部でデータを読み込み、RawDataWaveを生成する共通メソッド
        function createdRawDataWave = createInternal(obj, waveType, date, measuredFreq, conditions, labels, isNeedCorrect, correctConditions)
            
            conditionsLength = length(conditions);
            sources = append(RawDataCreatorWave.sourcePathHeader, date, "/", conditions, "/ALLDATA.csv");
            
            % データを格納するためのセル配列を初期化 (旧版と同様のデータ収集構造)
            timeCell = cell(1, conditionsLength);
            timeCell_second = cell(1, conditionsLength);
            capacitanceCell_raw = cell(1, conditionsLength); % 生のCapaデータ
            waveDataCell_tmp = cell(1, conditionsLength); % VF/Prデータ
            
            % 外れ値除去のための論理配列
            idx_rm_common_all = cell(1, conditionsLength); 
    
            for i = 1:conditionsLength
                % 1. データ読み込み
                tmp = readmatrix(sources(i));
                
                % 列の並びは実験日によって違う (RawDataColumns.m を参照)
                col = RawDataColumns.forDate(string(date));
                time = tmp(51:end, col.time);
                Capacitance = tmp(51:end, col.capacitance);
                upstreamPressure = tmp(51:end, col.upstreamPressure);

                numCols = size(tmp, 2);
                if numCols >= col.throatPressure
                    throatPressure = tmp(51:end, col.throatPressure);
                else
                    % 古いデータでスロート圧力の列が無い場合の代替処理 (以前と同じく3列目を使う)
                    throatPressure = tmp(51:end, 3);
                    warning('%s/%s: %d列目が無いため, 代わりに3列目を差圧の計算に使いました.', date, conditions(i), col.throatPressure);
                end

                DifferentialPressure = upstreamPressure - throatPressure;
                LiquidFlowRate = tmp(51:end, col.liquidFlowRate);
                GasFlowRate = tmp(51:end, col.gasFlowRate);
                
                % 2. 外れ値処理と共通NaNインデックスの特定
                % 物理的にありえない値だけを除く (PlausibleRange.m を参照).
                % 以前の rmoutliers は液の橋やスラグの差圧ピークまで消していたので使わない.
                idx_rm_capa = PlausibleRange.capacitanceOutliers(Capacitance);
                idx_rm_dp = PlausibleRange.diffPressureOutliers(DifferentialPressure);
                idx_rm_common = idx_rm_capa | idx_rm_dp; % <--- 共通の外れ値インデックス (片方が異常なら両方除く)
                idx_rm_common_all{i} = idx_rm_common; % 後で利用するため保存
                
                % 3. WaveTypeに応じたデータ選択とNaN置換
                if strcmp(waveType, "VF")
                    WaveData = Capacitance;
                    RawCapaData = Capacitance;
                elseif strcmp(waveType, "Pr")
                    WaveData = DifferentialPressure;
                    RawCapaData = nan(size(DifferentialPressure));
                end
                
                WaveData(idx_rm_common) = NaN; % <--- 外れ値をNaNに置換 (後の補正を想定)
                
                % 4. データを一時セル配列に格納
                timeCell{i} = time; 
                capacitanceCell_raw{i} = RawCapaData;
                waveDataCell_tmp{i} = WaveData; 
            end % <--- ループ終了。これで N個のサンプルデータがセル配列に格納された
    
            % 5. ループ後処理: 外れ値除去と時間の再計算、RawDataWaveオブジェクトの作成
            for i = 1:conditionsLength
                % 外れ値除去インデックスを取得
                idx_rm = idx_rm_common_all{i}; 
    
                % データを外れ値除去済みの状態に更新 (旧版のロジック)
                tmp_time = timeCell{i};
                timeCell{i} = tmp_time(~idx_rm);
                
                tmp_wave = waveDataCell_tmp{i};
                waveDataCell_tmp{i} = tmp_wave(~idx_rm);
                
                tmp_capa = capacitanceCell_raw{i};
                capacitanceCell_raw{i} = tmp_capa(~idx_rm); % これが RawDataのCapaになる
                
                % 単位を秒に直す (旧版のロジック)
                timeCell_i = timeCell{i};
                timeCell_second{i}(:,1) = (timeCell_i(:,1) - timeCell_i(1,1)) / 10^5;
                
                % 6. RawDataWave オブジェクトの作成 (単一のサンプルi)
                FlowRegimeLabel = RawDataCreatorWave.correctFlowRegime(conditions(i));
                
                createdRawDataWave(i) = RawDataWave(waveType, {waveDataCell_tmp{i}}, FlowRegimeLabel, ...
                    date, measuredFreq, {conditions(i)}, {labels(i)}, isNeedCorrect, {correctConditions(i)}, ...
                    {timeCell{i}}, {timeCell_second{i}}, {capacitanceCell_raw{i}}, {categorical(FlowRegimeLabel)}, ...
                    {LiquidFlowRate(1)}, {GasFlowRate(1)}); % <-- 流量はサンプルごとに定数として扱う
            end
        end
    end
    
    methods (Static)
        % 流量条件から流動様式ラベルに変換するメソッド (省略しない)
        function p = correctFlowRegime(condition)
            % 2026/11/20 の条件も追加 (L5G10, L5G15, L8G6, L9G3, L9G5, L0.3G1〜G3). 動画で確認済み:
            %   L0.3G1〜G3 は層状流とスラグ流が入れ替わる, L6G1/L6G3 はプラグ流と気泡流が混ざる.
            %   ここでは想定した流動様式をラベルにする (遷移の扱いは別に評価する).
            slug = ["L0.5G20" "L0.7G20" "L1G20" "L1.5G25" "L1.5G50" "L2G20" "L3G20" "L3G25" "L3G50" "L4.5G25" "L4.5G50" "L5G20" "L6G20" "L6G25" "L6G50" "L3G70" "L6G70" ...
                    "L5G10" "L5G15"];
            plug = ["L0.7G3" "L1G1" "L1G3" "L1.5G1" "L3G1" "L3G3" "L4.5G1" "L6G1" "L6G3"];
            bubbly = ["L10G1" "L10G3" "L10G20" "L10G70" "L14G1" "L14G3" "L14G20" "L14G50" "L14G70" ...
                      "L8G6" "L9G3" "L9G5"];
            annular = ["L0.5G70" "L0.7G70" "L1G70" "L1G90" "L3G90" "L5G90"];
            stratified = ["L0.05G1" "L0.05G3" "L0.05G10" "L0.5G1" "L0.5G3" "L0.7G1" ...
                          "L0.3G1" "L0.3G1.5" "L0.3G2" "L0.3G2.5" "L0.3G3"];
            if ismember(condition, slug)
                p = "Slug";
            elseif ismember(condition, plug)
                p = "Plug";
            elseif ismember(condition, bubbly)
                p = "Bubbly";
            elseif ismember(condition, annular)
                p = "Annular";
            elseif ismember(condition, stratified)
                p = "Stratified";
            else
                p = "Unknown";
            end
        end
    end
end