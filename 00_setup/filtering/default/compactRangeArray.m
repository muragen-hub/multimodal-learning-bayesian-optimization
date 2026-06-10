function [result] = compactRangeArray(array)
%COMPACTRANGEARRAY
%2*2次元配列の中身を見てある要素の最後の要素と次の要素の最初の要素が同じなら連続していると見て一つの要素にする処理を行う.
length = size(array,1);
length2 = size(array,2);
result = nan(length, length2); 
initIndex = 1;
tmpIndex = 1;
lastIndex = 2;
while lastIndex <= length
    if array(tmpIndex,2) == array(lastIndex,1)
        tmpIndex = tmpIndex+1;
        lastIndex = lastIndex+1;
    else
        result(initIndex,1) = array(initIndex,1);
        result(initIndex,2) = array(tmpIndex,2);
        tmpIndex = tmpIndex+1;
        initIndex= tmpIndex ;
        lastIndex = lastIndex+1;
    end
end
result(initIndex,1) = array(initIndex,1); %最後の部分の帳尻合わせ
result(initIndex,2) = array(tmpIndex,2);
idx = isnan(result(:,1));
result = result(~idx,:);
end

