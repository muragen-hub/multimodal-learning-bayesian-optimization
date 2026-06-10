classdef FormattedDataWave
    % FORMATTEDDATAWAVE 訓練とテストに備えてformatOptionに定められた形式に修正されたデータ (RawDataWave用)
    % このクラスは、DataFormatterWaveによってスライスされ、特徴量が抽出されたデータを格納する。
    
    properties
        option DataFormatterOptionWave % ★ Wave専用のオプションクラス
        date string
        condition (1,:) string
        label (1,:) string
        
        % ★ スライス化された波形データ: [N x Width x Channel] のセル配列（単一条件のためサイズ 1x1）
        waveDataCell (1,1) cell 
        
        % ★ 抽出された静的特徴量: [N x FeatureDim] のセル配列（単一条件のためサイズ 1x1）
        featureCell (1,1) cell 
        
        % ラベルデータ: [N x 1] のセル配列（単一条件のためサイズ 1x1）
        labelCell (1,1) cell 
        
        % 統計特徴量（主にデバッグ・分析用）
        average (1,1) cell
        max (1,1) cell
        min (1,1) cell
        
        % 流量情報（あれば格納。DataFormatterWaveでスライス毎の平均値を計算し格納する）
        liquidFlowRateOfEachData (1,1) cell
        gasFlowRateOfEachData (1,1) cell
    end
    
    methods
        function obj = FormattedDataWave(option, date, condition, label, ...
                                         waveDataCell, featureCell, labelCell, nameAndVar)
            arguments
                option DataFormatterOptionWave % ★ OptionWaveに変更
                date string
                condition (1,:) string
                label (1,:) string
                waveDataCell (1,1) cell        % 3D波形データ {N x W x C}
                featureCell (1,1) cell         % 特徴量データ {N x FeatureDim}
                labelCell (1,1) cell           % ラベルデータ {N x 1}
                
                % 統計値（オプションとして受け取るが、コンストラクタで計算しても良い）
                nameAndVar.average (1,1) cell = {[]};
                nameAndVar.max (1,1) cell = {[]};
                nameAndVar.min (1,1) cell = {[]};
                
                % 流量情報
                nameAndVar.liquidFlowRateOfEachData (1,1) cell = {[]};
                nameAndVar.gasFlowRateOfEachData (1,1) cell = {[]};
            end
            
            obj.option = option;
            obj.date = date;
            obj.condition = condition;
            obj.label = label;
            obj.waveDataCell = waveDataCell;
            obj.featureCell = featureCell;
            obj.labelCell = labelCell;
            
            % 統計値の設定 (主に FormatDataCore で抽出された静的特徴量を再利用する)
            obj.average = nameAndVar.average;
            obj.max = nameAndVar.max;
            obj.min = nameAndVar.min;
            
            obj.liquidFlowRateOfEachData = nameAndVar.liquidFlowRateOfEachData;
            obj.gasFlowRateOfEachData = nameAndVar.gasFlowRateOfEachData;
        end
        
        % ★ FormattedData にあった viewDataUniformity (ボックスチャート表示) などの分析メソッドを
        %    ここに追加することで、デバッグやレポート作成に役立ちます。
        % function [] = viewDataUniformity(obj,saveFolderName)
        %    ... (ロジックをここに移植)
        % end
    end
end