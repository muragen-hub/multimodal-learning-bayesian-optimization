function func = nonWavelet3Features(moveMaxMinRange)
arguments
    moveMaxMinRange {mustBePositive, mustBeInteger}
end
% wavelet packet analysis 4 level + movRange
    function result = nonCorrelationFeaturesCore(rawData, ~)
        conditionLength = length(rawData.conditions);
        processedCapa = cell(1,conditionLength);
        sourceData = rawData.capacitanceCell;
        dwtmode('per');
        for idx=1:conditionLength
            thatConditionData = sourceData{idx};
            sequenceLength = size(sourceData{idx},1);
            %移動最大最小値(移動レンジ)
            moveMax = movmax(thatConditionData,moveMaxMinRange);
            moveMin = movmin(thatConditionData,moveMaxMinRange);
            moveDiffOfMaxMin = moveMax-moveMin;

            T = wpdec(thatConditionData,4,'sym4');
            level3InitNum = depo2ind(2,[3 0]);
            WT1 = wprcoef(T,level3InitNum); 

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

            tmp2 = cat(2,WT1,moveDiffOfMaxMin,twoStepError); %ここ, 行べクトルか列ベクトルかで統一しなかったことの悪い点が出てる. cat(1,~~~)だと同じものを一つのシーケンスにしちゃう.
            processedCapa{idx} = tmp2;
        end
        creator = RawDataCreator();
        result = creator.createFromArray(rawData.date,rawData.measuredFreq,rawData.conditions,rawData.labels,rawData.isNeedCorrect,rawData.correctConditions,rawData.timeCell,rawData.timeCell_second,processedCapa,rawData.labelCell,rawData.liquidFlowRate,rawData.gasFlowRate);
    end
    func = @nonCorrelationFeaturesCore;
end

