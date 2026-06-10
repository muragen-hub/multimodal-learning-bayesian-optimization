classdef DataFormatterWave
    % DATAFORMATTERWAVE: ModifiedDataBeforeFormatWaveからFormattedDataWaveを生成するクラス
    
    properties (SetAccess = immutable)
        option DataFormatterOptionWave
        useFeature (1,1) logical % 特徴量を使用するかどうかのフラグ
    end
    
    methods (Access = public)
        % ★ 修正: コンストラクタを追加
        function obj = DataFormatterWave(option)
            arguments
                option DataFormatterOptionWave
            end
            obj.option = option;
            % Optionから特徴量フラグを取得
            obj.useFeature = option.useFeature; 
        end
        
        function formattedData = Format(obj, modifiedDataBeforeFormatWave)
    arguments
        obj DataFormatterWave
        modifiedDataBeforeFormatWave ModifiedDataBeforeFormatWave 
    end
    
    % ModifiedDataBeforeFormatWaveから RawDataWaveオブジェクト配列 (1x12) を取り出す
    rawDataWaveArray = modifiedDataBeforeFormatWave.modifiedRawDataWave;
    numSamples = length(rawDataWaveArray);
    
    % 結合結果を格納するセル配列を初期化
    waveData3D_all = {};
    featureMat_all = {};
    labelMat_all = {};
    avg_all = {};
    maxV_all = {};
    minV_all = {};
    liqFlow_all = {};
    gasFlow_all = {};
    
    % ループ処理: 全ての RawDataWave (12個の条件) に対してデータ拡張を実行
    for i = 1:numSamples
        rawWave = rawDataWaveArray(i);
        
        % 1. データとメタデータの取得 (i番目の RawDataWave から)
        % RawDataWaveのプロパティは 1x1 cell なので、中身を取り出す
        rawWaveData = rawWave.WaveDataCell{1};
        labelValue = rawWave.labelCell{1};
        
        % NaNを含む行を削除
        dataToSlice = rawWaveData(~any(isnan(rawWaveData), 2), :); 
        
        % 2. データコア処理（スライディングウィンドウと特徴量抽出）
        % FormatDataCoreは 3Dデータ、特徴量、拡張後のラベル、その他の特徴量を出力
        [waveData3D, featureMat, labelMat, avg, maxV, minV, liqFlow, gasFlow] = ...
            obj.FormatDataCore(dataToSlice, labelValue, rawWave.liquidFlowRate{1}, rawWave.gasFlowRate{1});
        
        % 3. 処理結果を結合用セル配列に格納 (垂直結合)
        waveData3D_all = [waveData3D_all; {waveData3D}];  % 3D配列をセルに格納
        featureMat_all = [featureMat_all; {featureMat}];  % 行列をセルに格納
        labelMat_all = [labelMat_all; {labelMat}];
        avg_all = [avg_all; {avg}];
        maxV_all = [maxV_all; {maxV}];
        minV_all = [minV_all; {minV}];
        liqFlow_all = [liqFlow_all; {liqFlow}];
        gasFlow_all = [gasFlow_all; {gasFlow}];
    end
    
    % 4. FormattedDataWave の生成 (全ての M x 1 セル配列を単一の行列に結合し、1x1 cell でラッピング)
    
    % ラベルは categorical に結合し直す 
    labelMat_combined = vertcat(labelMat_all{:});
    
    % ★ 修正 1: 波形データと特徴量データを単一の行列に結合
    waveData3D_combined = vertcat(waveData3D_all{:}); 
    featureMat_combined = vertcat(featureMat_all{:}); 
    
    % ★ 修正 2: conditions と labels の 1x1 cell のラッパーを外し、スカラーの string を取得
    condition_scalar = rawDataWaveArray(1).conditions{1};
    label_scalar     = rawDataWaveArray(1).labels{1};
    
    formattedData = FormattedDataWave(...
        obj.option, ...
        rawDataWaveArray(1).date, ...
        condition_scalar, ...           % スカラーの string
        label_scalar, ...               % スカラーの string
        {waveData3D_combined}, ...      % ★ 修正適用: 結合した行列を 1x1 cell でラッピング
        {featureMat_combined}, ...      % ★ 修正適用: 結合した行列を 1x1 cell でラッピング
        {labelMat_combined}, ...        % categorical配列を 1x1 cell でラッピング
        'average', {vertcat(avg_all{:})}, ...         % ★ 修正 3: optional argsも結合&ラッピング
        'max', {vertcat(maxV_all{:})}, ...
        'min', {vertcat(minV_all{:})}, ...
        'liquidFlowRateOfEachData', {vertcat(liqFlow_all{:})}, ...
        'gasFlowRateOfEachData', {vertcat(gasFlow_all{:})});
end
    end % <--- methods (Access = public) の終わりに合わせる
    
    methods(Access=private)
        function [waveData3D, featureMat, labelMat, avg, maxV, minV, liqFlowRate, gasFlowRate] = ...
                 FormatDataCore(obj, dataToSlice, labelValue, rawLiqFlow, rawGasFlow)
            % dataToSlice: [Time x Channel]
            
            % 1. オプションと次元の取得
            stride = obj.option.stride;
            dataWidth = obj.option.dataWidth;
            intervalBetweenData = obj.option.interval;
            
            nRows = size(dataToSlice, 1);
            nChannels = size(dataToSlice, 2); % 通常は 1
            
            % 2. インデックス計算
            oneDataSequence = intervalBetweenData * (dataWidth - 1) + dataWidth;
            datasetAmount = floor((nRows - oneDataSequence) / stride + 1);
            
            if datasetAmount <= 0
                waveData3D = zeros(0, dataWidth, nChannels);
                featureMat = zeros(0, 0);
                labelMat = categorical.empty(0, 1);
                avg = []; maxV = []; minV = []; liqFlowRate = []; gasFlowRate = [];
                return;
            end
            
            startIdx = 1:stride:(nRows - oneDataSequence + 1);
            startIdx = startIdx(1:datasetAmount);
            
            % 間隔を考慮したオフセットベクトル
            offsetVector = (0:(dataWidth - 1))' * (intervalBetweenData + 1);
            seqIdx = offsetVector + startIdx;
            
            % 3. 波形データ (3D配列) の生成
            % [N*Width x Channel] 行列
            waveMat = dataToSlice(seqIdx(:), :);
            % [Width x N x Channel] にリシェイプ
            waveReshape = reshape(waveMat, dataWidth, datasetAmount, nChannels);
            % [N x Width x Channel] にパーミュート (学習向け)
            waveData3D = permute(waveReshape, [2 1 3]); % N x W x C
            
            % 4. ラベル生成
            labelMat = repmat(labelValue, datasetAmount, 1);
            
            % 5. 流量データ (各スライスに対応する流量の平均値を計算)
            liqFlowRate = zeros(datasetAmount, 1);
            gasFlowRate = zeros(datasetAmount, 1);
            
            % RawDataWaveの流量データも波形と同じ長さを持つことを想定し、スライスして平均
            if ~isempty(rawLiqFlow) && numel(rawLiqFlow) >= nRows
                liqMat = rawLiqFlow(seqIdx(:));
                gasMat = rawGasFlow(seqIdx(:));
                % [Width x N] にリシェイプして平均
                liqFlowRate = mean(reshape(liqMat, dataWidth, datasetAmount), 1).'; 
                gasFlowRate = mean(reshape(gasMat, dataWidth, datasetAmount), 1).';
            end
            
            % 6. 特徴量抽出 (静的特徴量)
            avg = squeeze(mean(waveData3D, 2)); % 平均 [N x C]
            maxV = squeeze(max(waveData3D, [], 2));
            minV = squeeze(min(waveData3D, [], 2));
            range = maxV - minV;              % 範囲 [N x C]
            
            % datasetAmount=1 の場合の squeeze 対策
            if datasetAmount == 1 
                avg = avg.'; maxV = maxV.'; minV = minV.'; range = range.';
            end
            
            featureMat = zeros(datasetAmount, 0); % 初期化
            if obj.useFeature
                % 抽出された静的特徴量（ここでは平均と範囲）を結合 [N x (2*C)]
                featureMat = [avg, range];
            end
        end
    end
end