function func = WPof156()
arguments
end
% wavelet packet analysis 1,5,6. 
    function result = nonCorrelationFeaturesCore(rawData, ~)
        conditionLength = length(rawData.conditions);
        processedCapa = cell(1,conditionLength);
        sourceData = rawData.capacitanceCell;
        dwtmode('per');
        for idx=1:conditionLength
            thatConditionData = sourceData{idx};
           
            T = wpdec(thatConditionData,4,'sym4');
            level3InitNum = depo2ind(2,[3 0]);
            WT1 = wprcoef(T,level3InitNum ); 
            WT5 = wprcoef(T,level3InitNum +4);
            WT6 = wprcoef(T,level3InitNum +5);
            tmp2 = cat(2,WT1,WT5,WT6); %ここ, 行べクトルか列ベクトルかで統一しなかったことの悪い点が出てる. cat(1,~~~)だと同じものを一つのシーケンスにしちゃう.
            processedCapa{idx} = tmp2;
        end
        creator = RawDataCreator();
        result = creator.createFromArray(rawData.date,rawData.measuredFreq,rawData.conditions,rawData.labels,rawData.isNeedCorrect,rawData.correctConditions,rawData.timeCell,rawData.timeCell_second,processedCapa,rawData.labelCell,rawData.liquidFlowRate,rawData.gasFlowRate);
    end
    func = @nonCorrelationFeaturesCore;
end

