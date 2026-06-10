function [combinedFormedData] = combineFormedData(cellFormedData1, cellFormedData2)
%COMBINEFORMEDDATA 適当な長さ分だけある行数だけ連なったデータが,各条件ごとにセル配列になったものを二つくっつける関数0.
%合体した後のデータの中身の順番としては, 第一引数の方が先に来ます.
%
    conditionsLength1 = length(cellFormedData1);
    conditionsLength2 = length(cellFormedData2);

    if  conditionsLength1 ~= conditionsLength2
        disp("入力された二つのデータの長さが違います. 条件が二つのデータで揃っているか確認してください");
    end

    combinedFormedData = cellFormedData1;

    for i=1:conditionsLength1
           combinedFormedData{i}=vertcat(combinedFormedData{i},cellFormedData2{i});    
    end
end

