function func = almostAllBranch(moveMeanRange, moveMaxMinRange,moveSTDRange)
arguments
    moveMeanRange {mustBePositive,mustBeInteger}
    moveMaxMinRange {mustBePositive, mustBeInteger}
    moveSTDRange {mustBePositive, mustBeInteger}
end
%almostAllInput 考えられるほぼ全ての入力を与えてみる. 特徴量調査用. 
    function result = qiangXuBranchCore(rawData, ~)
        sourceData = rawData.capacitanceCell;
        conditionLength = length(rawData.conditions);
        processedCapa = cell(1,conditionLength);
        for idx=1:conditionLength
            sequenceLength = size(sourceData{idx},1);
            thatConditionData = sourceData{idx};
            %移動平均　このようにスライディングウィンドウで計算した特徴量はローリング特徴量とも呼ばれるらしい.
            moveMeanData = movmean(thatConditionData,moveMeanRange);
            %移動最大最小値(移動レンジ)
            moveMax = movmax(thatConditionData,moveMaxMinRange);
            moveMin = movmin(thatConditionData,moveMaxMinRange);
            moveDiffOfMaxMin = moveMax-moveMin;
            %移動標準偏差
            movSTD = movstd(thatConditionData, moveSTDRange);
            %移動絶対偏差 (移動平均のウィンドウサイズに合わせないと不自然)
            movError = thatConditionData-moveMeanData;
            %偏差平均を平均の代わりに使って求めた移動標準偏差. 恐らく摂動の影響がなくなった場合の流動の大局的な特徴が抽出できる?
            movAbsoluteStandardDeviation = sqrt((movsum(abs(thatConditionData-movError),moveSTDRange).^2) ./ (moveSTDRange-1));
            %1-delay1段階階差
            minusArray = zeros(sequenceLength,1);
            minusArray(2:end) = thatConditionData(1:end-1);
            minusArray(1) = 0;
            oneStepError = thatConditionData -  minusArray;
            oneStepError(1) = oneStepError(2)*2-oneStepError(3); % 外挿
            %1-delya2段階階差
            minusArray = zeros(sequenceLength,1);
            minusArray(2:end) = oneStepError(1:end-1);
            minusArray(1) = 0;
            twoStepError = oneStepError  -  minusArray;
            twoStepError(1) = twoStepError(2)*2-twoStepError(3); % 外挿
            %1-delay3段階階差 (3次関数の影響まで削除)
            minusArray = zeros(sequenceLength,1);
            minusArray(2:end) = twoStepError(1:end-1);
            minusArray(1) = 0;
            threeStepError = twoStepError -  minusArray;
            threeStepError(1) = threeStepError(2)*2-threeStepError(3); % 外挿
            %1-delay4段階階差
            minusArray = zeros(sequenceLength,1);
            minusArray(2:end) =  threeStepError(1:end-1);
            minusArray(1) = 0;
            fourStepError = threeStepError-  minusArray;
            fourStepError(1) = fourStepError(2)*2-fourStepError(3); % 外挿
            clear minusArray;
            %一階微分の中心差分　(2次精度) これいらないわ. やってることが階差と同じ. 
            %CenterDiffOfFirstOrderSecondAccuracy= zeros(sequenceLength,1);
            %oneStepFuture =  thatConditionData(2:end);
            %oneStepPast = thatConditionData(1:end-1);
            %CenterDiffOfFirstOrderSecondAccuracy(2:end-1) = oneStepFuture -oneStepPast;
            %CenterDiffOfFirstOrderSecondAccuracy(1) = -3*thatConditionData(1)+4*thatConditionData(2)-thatConditionData(3); % 二次精度1階片側差分
            %CenterDiffOfFirstOrderSecondAccuracy(end) = thatConditionData(end-2)-4*thatConditionData(end-1)+3*thatConditionData(end); % 二次精度1階片側差分
            %二階微分の中心差分　(2次精度)　 https://takun-physics.net/9346/とか
            %CenterDiffOfSecondOrderSecondAccuracy= zeros(sequenceLength,1);
            %oneStepFuture =  thatConditionData(2:end);
            %oneStepPast = thatConditionData(1:end-1);
            %CenterDiffOfSecondOrderSecondAccuracy(2:end-1) = oneStepFuture -oneStepPast-2*thatConditionData(2:end-1);
            %CenterDiffOfSecondOrderSecondAccuracy(1) = 2*thatConditionData(1)-5*thatConditionData(2)+4*thatConditionData(3)-thatConditionData(4);
            %CenterDiffOfSecondOrderSecondAccuracy(end) = -thatConditionData(end-3)+4*thatConditionData(end-2)-5*thatConditionData(end-1)+2*thatConditionData(end);
            %累積値
            accumurate = cumsum(thatConditionData);
            %対数特徴量
            %ここ　もし負の値があった売位はlog出来ないので0.001とかにする
            minusIndex = thatConditionData<0;
            thatConditionData(minusIndex) = 0.001;
            logFeatures = reallog(thatConditionData);
            %まとめ
            tmp2 = cat(2,moveMeanData,moveDiffOfMaxMin,movSTD,movError,movAbsoluteStandardDeviation,oneStepError,twoStepError,threeStepError,fourStepError,accumurate,logFeatures); %ここ, 行べクトルか列ベクトルかで統一しなかったことの悪い点が出てる. cat(1,~~~)だと同じものを一つのシーケンスにしちゃう.
            processedCapa{idx} = tmp2;
        end
        creator = RawDataCreator();
        result = creator.createFromArray(rawData.date,rawData.measuredFreq,rawData.conditions,rawData.labels,rawData.isNeedCorrect,rawData.correctConditions,rawData.timeCell,rawData.timeCell_second,processedCapa,rawData.labelCell,rawData.liquidFlowRate,rawData.gasFlowRate);
    end
func = @qiangXuBranchCore;
end

