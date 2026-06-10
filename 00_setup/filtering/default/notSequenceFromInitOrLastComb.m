function [result] = notSequenceFromInitOrLastComb(total,extractedNum)
%NOTSEQUENCEFROMINITORLASTCOMB ハイパス, ローパスの方がデジタルフィルタの特徴として,
%連続してカットする際には向いているため, バンドストップするときにその部分を抜いた場合を行うための補助的な関数.
%indexとして用いることが期待され, 最初と最後から連続してつながっているような組み合わせを除去した組み合わせを返す.
array = 1:1:total;
tmp = nchoosek(array, extractedNum);
result = zeros(total, extractedNum); 
for index = 1:length(tmp) %matlabはiが複素数という意味を持ってしまっていて怖いので下手にiなど1文字変数を使わない
    fromInitSequence = tmp(index,1) == 1 && (tmp(index,end) == 1+extractedNum-1); %最初から連続してhoge点分だけ取ってきてしまっている場合
    fromLastSequence = tmp(index,end) == total && (tmp(index,end-extractedNum+1) == total-extractedNum+1); %最後から連続してhoge点文だけ取ってきてしまっている場合
    isInvalid = fromInitSequence || fromLastSequence;
    if ~isInvalid
        result(index,:) = tmp(index,:); 
    end
end
idx = result(:,1) == 0; %0で始まる部分はカットしてよいものとする. (indexはmatlabは1からなので可能)
result = result(~idx,:);
end