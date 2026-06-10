function func = threeLevelWaveletPacket()
% wavelet packet analysis 4 level
    function result = nLevelWaveletPacketCore(rawData, ~)
        conditionLength = length(rawData.conditions);
        processedCapa = cell(1,conditionLength);
        sourceData = rawData.capacitanceCell;
        dwtmode('per');
        for idx=1:conditionLength
            thatConditionData = sourceData{idx};
            T = wpdec(thatConditionData,4,'sym4');
            level3InitNum = depo2ind(2,[3 0]);
            WT1 = wprcoef(T,level3InitNum ); 
            WT2 = wprcoef(T,level3InitNum +1);
            WT3 = wprcoef(T,level3InitNum +2);
            WT4 = wprcoef(T,level3InitNum +3);
            WT5 = wprcoef(T,level3InitNum +4);
            WT6 = wprcoef(T,level3InitNum +5);
            WT7 = wprcoef(T,level3InitNum +6);
            WT8 = wprcoef(T,level3InitNum +7);
            tmp2 = cat(2,WT1,WT2,WT3,WT4,WT5,WT6,WT7,WT8); %ここ, 行べクトルか列ベクトルかで統一しなかったことの悪い点が出てる. cat(1,~~~)だと同じものを一つのシーケンスにしちゃう.
            processedCapa{idx} = tmp2;
        end
        creator = RawDataCreator();
        result = creator.createFromArray(rawData.date,rawData.measuredFreq,rawData.conditions,rawData.labels,rawData.isNeedCorrect,rawData.correctConditions,rawData.timeCell,rawData.timeCell_second,processedCapa,rawData.labelCell,rawData.liquidFlowRate,rawData.gasFlowRate);
    end
    func = @nLevelWaveletPacketCore;
end

