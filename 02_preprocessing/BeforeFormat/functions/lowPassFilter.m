function func = lowPassFilter(limitFreq)
%LOWPASSFILTER 取得したデータから低周波数側の周波数を除去したデータを出力する.
%受け取ったTimeTable形式のデータ(サンプリングの間隔が等間隔であることが条件)に対してローパスフィルタを作用させる.
%測定時のサンプリング周波数に対して, 1/2以上の値の周波数でフィルタをかけてもオールパスフィルタになることに注意.例えば, 元々50Hzでデータを取ったなら25Hzの周波数までしか再現できないので, 25Hz以上の閾値でローパスをかけても意味はない.(標本化定理)
%cellOfConstFreqTimeTable: サンプリング周波数が一定であるタイムテーブル形式のデータ
%limitFreq: 通す限界の周波数.
arguments
    limitFreq  {mustBeNumeric}
end
    function processedData = lowPassFilterCore(rawData, ~)
        conditionsLength = length(rawData.conditions);

        cellOfFilteredTimeTable = cell(1, conditionsLength);
        processedCapa = cell(1,conditionsLength);
        for j = 1:conditionsLength
            processedCapa{j} = rawData.capacitanceCell{j} ;%- rawData.representative.average(j);
            cellOfFilteredTimeTable{j} = timetable(rawData.timeCell_second{j},processedCapa{j},'VariableNames',{'Capacitance'});
            cellOfFilteredTimeTable{j} = lowpass(cellOfFilteredTimeTable{j}, limitFreq);
            processedCapa{j} = cellOfFilteredTimeTable{j}.Capacitance; %+  rawData.representative.average(j);
        end
        creator = RawDataCreator();
        processedData = creator.createFromArray(rawData.date,rawData.measuredFreq,rawData.conditions,rawData.labels,rawData.isNeedCorrect,rawData.correctConditions,rawData.timeCell,rawData.timeCell_second,processedCapa,rawData.labelCell,rawData.liquidFlowRate,rawData.gasFlowRate);

    end
func = @lowPassFilterCore;
end