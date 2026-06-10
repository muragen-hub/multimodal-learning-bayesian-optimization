function [cellOfFilteredTimeTable] = lowPassFilterWrapper(cellOfConstFreqTimeTable, thresholdFreq)
%LOWPASSFILTERWRAPPER
%受け取ったTimeTable形式のデータ(サンプリングの間隔が等間隔であることが条件)に対してローパスフィルタを作用させる.
%測定時のサンプリング周波数に対して, 1/2以上の値の周波数でフィルタをかけてもオールパスフィルタになることに注意.例えば, 元々50Hzでデータを取ったなら25Hzの周波数までしか再現できないので, 25Hz以上の閾値でローパスをかけても意味はない.(標本化定理)
%cellOfConstFreqTimeTable: サンプリング周波数が一定であるタイムテーブル形式のデータ
%[TODO] steepnessの影響について調査するべき.

conditionsLength = length(cellOfConstFreqTimeTable);
cellOfFilteredTimeTable = cell(1, conditionsLength);
    for i = 1:conditionsLength
        cellOfFilteredTimeTable{i} = lowpass(cellOfConstFreqTimeTable{i},thresholdFreq);
    end
    clear cellOfConstFreqTimeTable;
end

