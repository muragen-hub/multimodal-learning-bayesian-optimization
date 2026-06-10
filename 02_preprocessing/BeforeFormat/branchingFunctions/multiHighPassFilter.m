function func = multiHighPassFilter(limitFreq, isRemainOriginal)
%MULTIHIGHPSSFILTER RawData側に対応したmultiHighPassfilter
arguments
    limitFreq (1,:) {mustBeNumeric}
    isRemainOriginal logical
end
function processedData = highPassFilterCore(rawData, ~)
        conditionsLength = length(rawData.conditions);

        cellOfFilteredTimeTable = cell(1, conditionsLength);
        processedCapa = cell(1,conditionsLength);
        
        for j = 1:conditionsLength
            %ハイパスフィルタをかけないのも一応残しておく. 
            if(isRemainOriginal)
                processedCapa{j}(:,1) = rawData.capacitanceCell{j} - rawData.representative.average{j};
                cellOfFilteredTimeTable{j} = timetable(rawData.timeCell_second{j},processedCapa{j}(:,1),'VariableNames',{'Capacitance'});
                processedCapa{j}(:,1) = cellOfFilteredTimeTable{j}.Capacitance +  rawData.representative.average{j};
           
                for k = 2:(length(limitFreq)+1)
                processedCapa{j}(:,k) = rawData.capacitanceCell{j}- rawData.representative.average{j};
                cellOfFilteredTimeTable{j} = timetable(rawData.timeCell_second{j},processedCapa{j}(:,k),'VariableNames',{'Capacitance'});
                cellOfFilteredTimeTable{j} = highpass(cellOfFilteredTimeTable{j}, limitFreq(k-1));
                processedCapa{j}(:,k) = cellOfFilteredTimeTable{j}.Capacitance +  rawData.representative.average{j};
                end
            else
                for k = 1:(length(limitFreq))
                processedCapa{j}(:,k) = rawData.capacitanceCell{j} - rawData.representative.average{j};
                cellOfFilteredTimeTable{j} = timetable(rawData.timeCell_second{j},processedCapa{j}(:,k),'VariableNames',{'Capacitance'});
                cellOfFilteredTimeTable{j} = highpass(cellOfFilteredTimeTable{j}, limitFreq(k));
                processedCapa{j}(:,k) = cellOfFilteredTimeTable{j}.Capacitance +  rawData.representative.average{j};
                end
            end

        end
        %端点付近が汚いので除外
        edgeExcludeCapa = cell(1, conditionsLength);
        for j = 1:conditionsLength
            edgeExcludeCapa{j} = processedCapa{j}(20:end-20,:);
        end

        rawDataCretor = RawDataCreator();
        processedData = rawDataCretor.createFromArray(rawData.date,rawData.measuredFreq,rawData.conditions,rawData.labels,rawData.isNeedCorrect,rawData.correctConditions,rawData.timeCell,rawData.timeCell_second,processedCapa,rawData.labelCell,rawData.liquidFlowRate,rawData.gasFlowRate);
    end
func = @highPassFilterCore;  
end

