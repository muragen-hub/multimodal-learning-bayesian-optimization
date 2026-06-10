classdef DataFormatterTwo
    properties(SetAccess = immutable)
        option
        dataWidth (1,1) double
        timeSteps (1,1) double
        channels (1,1) double
        featureChannels (1,1) double
        
        % ✅ 新しいフラグ
        useWaveform (1,1) logical = false;
        useFeature (1,1) logical = true;
    end

    methods(Access = public)
        function obj = DataFormatterTwo(option)
            arguments
                option DataFormatterOption
            end

            obj.option = option;
            obj.dataWidth = option.dataWidth;
            %obj.timeSteps = option.timeSteps;
            obj.timeSteps = option.dataWidth; % 💡 dataWidthを使用
            obj.channels = option.channels;
            obj.featureChannels = option.featureChannels;
            obj.useWaveform = option.useWaveform;
            obj.useFeature = option.useFeature;
            
            if ~obj.useWaveform && ~obj.useFeature
                error('DataFormatterTwo: useWaveform または useFeature の少なくとも一方を true に設定してください。');
            end
        end

        function formattedData = Format(obj, modifiedDataBeforeFormatTwo)
    arguments
        obj DataFormatterTwo
        modifiedDataBeforeFormatTwo ModifiedDataBeforeFormatTwo
    end
    
    % --- 【✨ 追加: obj.useWaveform の値を確認 (メソッド開始時)】 ---
    disp(['--- 🔍 DataFormatterTwo.Format: obj.useWaveform の値: ', num2str(obj.useWaveform), ' ---']);
    % --------------------------------------------------------------------
    
    rawDataTwo = modifiedDataBeforeFormatTwo.rawDataTwo;

    % --- コア処理 ---
    [capacitance, label, feature, differentialFeature, averageTmp, maxTmp, minTmp, ...
        liquidFlowRate, gasFlowRate, differentialPressure] = ...
        obj.FormatDataCoreVectorized(rawDataTwo);

    % --- 転置して 1xN のセルに統一 ---
    N = numel(capacitance);
    capacitanceT = capacitance.';
    labelT       = label.';
    featureT     = cell(1, N);
    diffFeatureT = cell(1, N);
    differentialPressureT = differentialPressure.';

    for i = 1:N
        featureT{i}     = feature(:, i);     % 静電容量特徴量
        diffFeatureT{i} = differentialFeature(:, i); % 差圧特徴量
    end

    averageTmpT      = averageTmp.';
    maxTmpT          = maxTmp.';
    minTmpT          = minTmp.';
    liquidFlowRateT  = liquidFlowRate.';
    gasFlowRateT     = gasFlowRate.';

    % --- ✅ 機械学習用セル: 静的特徴量のみを格納するように修正 ---
    featureX_for_MLCell = cell(1, N);
    
    for i = 1:N
        % --- 静的特徴量の結合ロジックのみを保持 ---
        feature_static_combined = [];

        if obj.useFeature
            % 静電容量特徴量を転置して追加
            cap_feature = featureT{i}.';
            if ~isempty(cap_feature)
                feature_static_combined = [feature_static_combined, cap_feature];
            end
            
            % 差圧特徴量を転置して追加
            diff_feature = diffFeatureT{i}.';
            if ~isempty(diff_feature)
                feature_static_combined = [feature_static_combined, diff_feature];
            end
        end
        
        % featureX_for_MLCell には静的特徴量のみを格納 (サイズは [1 8] になるはず)
        featureX_for_MLCell{i} = feature_static_combined;
        
        % --- 【✨ デバッグコード (最終確認) 】 ---
        if i == 1 % 最初の要素のみデバッグ情報を出力
            disp(' ');
            disp('--- 🔍 DataFormatterTwo.Format: i=1 のデータサイズ確認 (静的特徴量のみ) ---');
            
            % 波形データの平坦化ロジックは削除したため、cap_wave_flattened と feature_static は存在しない
            % 代わりに、最終結合サイズを直接出力
            disp(['  最終結合サイズ (静的特徴量): ', mat2str(size(featureX_for_MLCell{i}))]);
            disp('----------------------------------------------------');
            disp(' ');
        end
        % ---------------------------------------
    end
    
    % --- FormattedDataTwo の生成 (位置引数14個) ---
    % 波形データは capacitanceT (5) と differentialPressureT (6) に 3D 形式で保持される
    formattedData = FormattedDataTwo(...
        obj.option, ...
        rawDataTwo.date, ...
        rawDataTwo.conditions, ...
        rawDataTwo.labels, ...
        capacitanceT, ...
        differentialPressureT, ...
        rawDataTwo.flowRegimeCell, ...
        featureT, ...
        diffFeatureT, ...
        featureX_for_MLCell, ... % 10番目の位置 (静的特徴量のみの結合)
        labelT, ...
        averageTmpT, ...
        maxTmpT, ...
        minTmpT, ...
        "liquidFlowRateOfEachData", liquidFlowRateT, ...
        "gasFlowRateOfEachData", gasFlowRateT);
        end
    end

    methods(Access = private)
        function [capacitance, label, feature, differentialFeature, averageTmp, maxTmp, minTmp, ...
                      liquidFlowRate, gasFlowRate, differentialPressure] = FormatDataCoreVectorized(obj, rawDataTwo)

            conditionsLength = numel(rawDataTwo.conditions);
            dataWidth = obj.option.dataWidth;
            stride = obj.option.stride;
            intervalBetweenData = obj.option.intervalBetweenData;

            featureNumber = 4;
            feature             = cell(featureNumber, conditionsLength);
            differentialFeature = cell(featureNumber, conditionsLength);

            capacitance    = cell(conditionsLength,1);
            label          = cell(conditionsLength,1);
            averageTmp     = cell(conditionsLength,1);
            maxTmp         = cell(conditionsLength,1);
            minTmp         = cell(conditionsLength,1);
            liquidFlowRate = cell(conditionsLength,1);
            gasFlowRate    = cell(conditionsLength,1);
            differentialPressure = cell(conditionsLength,1);

            for i = 1:conditionsLength
                rawCap  = rawDataTwo.capacitanceCell{i};
                rawDiff = rawDataTwo.differentialPressure{i};

                if isempty(rawCap) || isempty(rawDiff)
                    continue
                end

                nRows = size(rawCap,1);
                nChannels = size(rawCap,2);
                labelValue = rawDataTwo.labelCell{i};

                % --- データ分割 ---
                oneDataSequence = intervalBetweenData*(dataWidth-1)+dataWidth;
                datasetAmount = fix((nRows-oneDataSequence)/stride + 1);
                datasetAmount = min(datasetAmount, obj.option.lengthLimitInEachCondition);
                if datasetAmount <= 0
                    continue
                end

                startIdx = 1:stride:(nRows-oneDataSequence+1);
                startIdx = startIdx(1:datasetAmount);
                offsetVector = (0:(dataWidth-1))'*(intervalBetweenData+1);
                seqIdx = offsetVector + startIdx;

                % --- キャパシタンス波形 ---
                capMat = rawCap(seqIdx(:), :);
                capReshape = reshape(capMat, dataWidth, datasetAmount, nChannels);
                capacitance{i} = permute(capReshape, [2 1 3]);

                % --- 差圧波形 ---
                nDiffChannels = size(rawDiff,2);
                diffMat = rawDiff(seqIdx(:), :);
                diffReshape = reshape(diffMat, dataWidth, datasetAmount, nDiffChannels);
                differentialPressure{i} = permute(diffReshape, [2 1 3]);

                % --- ラベル複製 ---
                label{i} = repmat(labelValue, datasetAmount,1);

                % --- 統計値 ---
                averageTmp{i} = squeeze(mean(capacitance{i},2,'omitnan'));
                maxTmp{i}     = squeeze(max(capacitance{i},[],2));
                minTmp{i}     = squeeze(min(capacitance{i},[],2));

                % --- 静電容量特徴量 ---
                feature{1,i} = diff(capacitance{i},2,2); %1行目：差分
                if nChannels==1
                    tempWPT = zeros(datasetAmount,dataWidth);
                    parfor j=1:datasetAmount
                        wpt_1 = modwpt(squeeze(capacitance{i}(j,:)),"sym4",3);
                        tempWPT(j,:) = wpt_1(1,:);
                    end
                    feature{2,i} = tempWPT;
                else
                    feature{2,i} = cell(datasetAmount,nChannels); %2行目：modwpt
                end
                avgExpand = repmat(averageTmp{i},1,dataWidth,1);
                feature{3,i} = capacitance{i}-avgExpand; %3行目：平均からの偏差
                feature{4,i} = maxTmp{i}-minTmp{i}; %4行目：範囲（唯一、時系列ではない）

                % --- 差圧特徴量 ---
                diffData = differentialPressure{i};
                differentialFeature{1,i} = diff(diffData,2,2);%5行目：差分
                diffAvg = squeeze(mean(diffData,2,'omitnan'));%6行目：平均（ノット時系列）
                differentialFeature{2,i} = diffAvg;
                diffAvgExpand = repmat(diffAvg,1,dataWidth,1);
                differentialFeature{3,i} = diffData-diffAvgExpand;%7行目：平均からの偏差
                differentialFeature{4,i} = squeeze(max(diffData,[],2)) - squeeze(min(diffData,[],2));%8行目：範囲（ノット時系列）

                % --- 流量 ---
                if isfield(rawDataTwo,'liquidFlowRate') && ~isempty(rawDataTwo.liquidFlowRate)
                    liqVec = rawDataTwo.liquidFlowRate{i}(:);
                    gasVec = rawDataTwo.gasFlowRate{i}(:);
                    if numel(liqVec) >= nRows
                        liqMat = liqVec(seqIdx(:));
                        gasMat = gasVec(seqIdx(:));
                        liquidFlowRate{i} = mean(reshape(liqMat,dataWidth,datasetAmount),1).';
                        gasFlowRate{i}    = mean(reshape(gasMat,dataWidth,datasetAmount),1).';
                    else
                        liquidFlowRate{i} = repmat(liqVec(1),datasetAmount,1);
                        gasFlowRate{i}    = repmat(gasVec(1),datasetAmount,1);
                    end
                end
            end
        end
    end
    end