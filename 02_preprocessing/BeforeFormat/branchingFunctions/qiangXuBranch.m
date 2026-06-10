function func = qiangXuBranch(moveMeanRange, moveMaxMinRange,moveSTDRange)
arguments
    moveMeanRange {mustBePositive,mustBeInteger}
    moveMaxMinRange {mustBePositive, mustBeInteger}
    moveSTDRange {mustBePositive, mustBeInteger}
end
%QIANGXUBRANCH QiangXuさんの論文のbranchのさせ方を行う. 
%移動平均, 移動最大最小値(移動レンジ), 移動標準偏差, 平均値からの偏差の絶対値の平均, 偏差平均を平均の代わりに使って求めた標準偏差
    function result = qiangXuBranchCore(rawData, ~)
        conditionLength = length(rawData.conditions);
        processedCapa = cell(1,conditionLength);
        sourceData = rawData.capacitanceCell;
        for idx=1:conditionLength
            thatConditionData = sourceData{idx};
            %移動平均
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
            tmp2 = cat(2,moveMeanData,moveDiffOfMaxMin,movSTD,movError,movAbsoluteStandardDeviation); %ここ, 行べクトルか列ベクトルかで統一しなかったことの悪い点が出てる. cat(1,~~~)だと同じものを一つのシーケンスにしちゃう.
            processedCapa{idx} = tmp2;
        end
        creator = RawDataCreator();
        result = creator.createFromArray(rawData.date,rawData.measuredFreq,rawData.conditions,rawData.labels,rawData.isNeedCorrect,rawData.correctConditions,rawData.timeCell,rawData.timeCell_second,processedCapa,rawData.labelCell,rawData.liquidFlowRate,rawData.gasFlowRate);
    end
    func = @qiangXuBranchCore;
end

