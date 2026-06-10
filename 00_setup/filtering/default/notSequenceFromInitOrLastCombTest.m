rangeArray = [0 5;5 10; 10 20;20 30;30 40];
total = length(rangeArray);
comb = 3;
aaa = notSequenceFromInitOrLastComb(total,comb)

for hoge = 1:length(aaa)
    neko = rangeArray(aaa(hoge,:),:);
    neko = compactRangeArray(neko)
end