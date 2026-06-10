function [cellOfFilteredTimeTable] = highPassFilterWrapper(cellOfConstFreqTimeTable, thresholdFreq)
%HIGHPASSFILTERWRAPPER
%受け取ったTimeTable形式のデータ(サンプリングの間隔が等間隔であることが条件)に対してハイパスフィルタを作用させる.
%cellOfConstFreqTimeTable: サンプリング周波数が一定であるタイムテーブル形式のデータ


conditionsLength = length(cellOfConstFreqTimeTable);
cellOfFilteredTimeTable = cell(1, conditionsLength);
    for i = 1:conditionsLength
        cellOfFilteredTimeTable{i} = highpass(cellOfConstFreqTimeTable{i},thresholdFreq);
    end
    clear cellOfConstFreqTimeTable;
end

