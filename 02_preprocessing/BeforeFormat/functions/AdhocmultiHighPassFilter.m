function func = AdhocmultiHighPassFilter(limitFreq, isRemainOriginal)
%HIGHPASSFILTER 取得したデータから低周波数側の周波数を除去したデータを出力する.
%受け取ったTimeTable形式のデータ(サンプリングの間隔が等間隔であることが条件)に対してローパスフィルタを作用させる.
%測定時のサンプリング周波数に対して, 1/2以上の値の周波数でフィルタをかけてもオールパスフィルタになることに注意.例えば, 元々50Hzでデータを取ったなら25Hzの周波数までしか再現できないので, 25Hz以上の閾値でローパスをかけても意味はない.(標本化定理)
%cellOfConstFreqTimeTable: サンプリング周波数が一定であるタイムテーブル形式のデータ
arguments
    limitFreq (1,:) {mustBeNumeric}
    isRemainOriginal logical
end
    function processedData = highPassFilterCore(multiVectorModifiedDataBeforeFormat, ~)
        conditionsLength = length(multiVectorModifiedDataBeforeFormat.rawData.conditions);

        cellOfFilteredTimeTable = cell(1, conditionsLength);
        processedCapa = cell(1,conditionsLength);
        
        for j = 1:conditionsLength
            %ハイパスフィルタをかけないのも一応残しておく. 
            if(isRemainOriginal)
                processedCapa{j}(:,1) = multiVectorModifiedDataBeforeFormat.rawData.capacitanceCell{j}- multiVectorModifiedDataBeforeFormat.rawData.representative.average(j);
                cellOfFilteredTimeTable{j} = timetable(multiVectorModifiedDataBeforeFormat.rawData.timeCell_second{j},processedCapa{j}(:,1),'VariableNames',{'Capacitance'});
                processedCapa{j}(:,1) = cellOfFilteredTimeTable{j}.Capacitance +  multiVectorModifiedDataBeforeFormat.rawData.representative.average(j);
           
                for k = 2:(length(limitFreq)+1)
                processedCapa{j}(:,k) = multiVectorModifiedDataBeforeFormat.rawData.capacitanceCell{j}- multiVectorModifiedDataBeforeFormat.rawData.representative.average(j);
                cellOfFilteredTimeTable{j} = timetable(multiVectorModifiedDataBeforeFormat.rawData.timeCell_second{j},processedCapa{j}(:,k),'VariableNames',{'Capacitance'});
                cellOfFilteredTimeTable{j} = highpass(cellOfFilteredTimeTable{j}, limitFreq(k-1));
                processedCapa{j}(:,k) = cellOfFilteredTimeTable{j}.Capacitance +  multiVectorModifiedDataBeforeFormat.rawData.representative.average(j);
                end
            else
                for k = 1:(length(limitFreq))
                processedCapa{j}(:,k) = multiVectorModifiedDataBeforeFormat.rawData.capacitanceCell{j}- multiVectorModifiedDataBeforeFormat.rawData.representative.average(j);
                cellOfFilteredTimeTable{j} = timetable(multiVectorModifiedDataBeforeFormat.rawData.timeCell_second{j},processedCapa{j}(:,k),'VariableNames',{'Capacitance'});
                cellOfFilteredTimeTable{j} = highpass(cellOfFilteredTimeTable{j}, limitFreq(k));
                processedCapa{j}(:,k) = cellOfFilteredTimeTable{j}.Capacitance +  multiVectorModifiedDataBeforeFormat.rawData.representative.average(j);
                end
            end

        end
        %端点付近が汚いので除外
        edgeExcludeCapa = cell(1, conditionsLength);
        for j = 1:conditionsLength
            edgeExcludeCapa{j} = processedCapa{j}(20:end-20,:);
        end


        processedData = MultiVectorModifiedDataBeforeFormat(multiVectorModifiedDataBeforeFormat.rawData,processedCapa);
    end
func = @highPassFilterCore;                                                                                
end