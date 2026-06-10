function func = bandBlockFilter(stopFreqs)
%BANDBLOCKFILTER 取得したデータから一定の区間の周波数を除去したデータを出力する.
%受け取ったTimeTable形式のデータ(サンプリングの間隔が等間隔であることが条件)に対してバンドストップフィルタを作用させる.
%測定時のサンプリング周波数に対して, 1/2以上の値の周波数でフィルタをかけてもオールパスフィルタになることに注意.例えば, 元々50Hzでデータを取ったなら25Hzの周波数までしか再現できないので, 25Hz以上の閾値でバンドストップをかけても意味はない.(標本化定理)
%cellOfConstFreqTimeTable: サンプリング周波数が一定であるタイムテーブル形式のデータ
%stopFreqs: 通さない周波数帯の二次元配列, 入力は例えば, 0から2Hz, 10から20Hz, 25から30Hzをカットするなら, [[0 2];[10 20];[25 30]]とする
arguments
    stopFreqs (:,:) {mustBeNumeric}
end

    function processedData = bandBlockFilterCore(rawData, ~)
        %arguments
        %    rawData RawData
        %    rawAllData RawAllDataBeforeFormat
        %end
        conditionsLength = length(rawData.conditions);

        cellOfFilteredTimeTable = cell(1, conditionsLength);
        processedCapa = cell(1,conditionsLength);
        for j = 1:conditionsLength
            stopsLength = size(stopFreqs,1);
            processedCapa{j} = rawData.capacitanceCell{j} ;%- rawData.representative.average(j);
            cellOfFilteredTimeTable{j} = timetable(rawData.timeCell_second{j},processedCapa{j},'VariableNames',{'Capacitance'});
            for i = 1:stopsLength
                cellOfFilteredTimeTable{j} = bandstop(cellOfFilteredTimeTable{j}, stopFreqs(i,:));
            end
            processedCapa{j} = cellOfFilteredTimeTable{j}.Capacitance ;%+  rawData.representative.average(j);
        end
        creator = RawDataCreator();
        processedData = creator.createFromArray(rawData.date,rawData.measuredFreq,rawData.conditions,rawData.labels,rawData.isNeedCorrect,rawData.correctConditions,rawData.timeCell,rawData.timeCell_second,processedCapa,rawData.labelCell,rawData.liquidFlowRate,rawData.gasFlowRate);
    end

func = @bandBlockFilterCore;
end

