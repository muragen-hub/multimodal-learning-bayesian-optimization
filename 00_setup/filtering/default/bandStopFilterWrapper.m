function [cellOfFilteredTimeTable] = bandStopFilterWrapper(cellOfConstFreqTimeTable, stopFreqs)
%BANDSTOPFILTERWRAPPER
%受け取ったTimeTable形式のデータ(サンプリングの間隔が等間隔であることが条件)に対してバンドストップフィルタを作用させる.
%測定時のサンプリング周波数に対して, 1/2以上の値の周波数でフィルタをかけてもオールパスフィルタになることに注意.例えば, 元々50Hzでデータを取ったなら25Hzの周波数までしか再現できないので, 25Hz以上の閾値でバンドストップをかけても意味はない.(標本化定理)
%cellOfConstFreqTimeTable: サンプリング周波数が一定であるタイムテーブル形式のデータ
%stopFreqs: 通さない周波数帯の二次元配列, 入力は例えば, 0から2Hz, 10から20Hz, 25から30Hzをカットするなら, [[0 2];[10 20];[25 30]]とする

conditionsLength = length(cellOfConstFreqTimeTable);
cellOfFilteredTimeTable = cell(1, conditionsLength);
for j = 1:conditionsLength
    stopsLength = size(stopFreqs,1);
    cellOfFilteredTimeTable{j} = cellOfConstFreqTimeTable{j};
    for i = 1:stopsLength
        cellOfFilteredTimeTable{j} = bandstop(cellOfFilteredTimeTable{j}, stopFreqs(i,:));
    end
end
clear cellOfConstFreqTimeTable;
end
