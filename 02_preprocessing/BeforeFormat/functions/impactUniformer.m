function processedData  = impactUniformer(multiVectorModifiedDataBeforeFormat, rawAllDataBeforeFormat)
%IMPACTUNIFORMER モデルの微分項に与えるインパクトが同じになるようにそろえる.
%そろえ方として, 微分値の最大をそろえるとか, 最小をそろえるとか色々あるけど, とりあえず最大最小をそろえて行く感じで. (もともと同じものをフィルタかけている場合なら, これをやっても環状流が判別負荷になるとかはないと思う)
arguments
    multiVectorModifiedDataBeforeFormat MultiVectorModifiedDataBeforeFormat
    rawAllDataBeforeFormat RawAllDataBeforeFormat
end

%このそろえ方はまずいかもしれない. originalのデータを超えるような高周波数側のデータが出てしまっている. それはよくないかも.
conditionLength = length(multiVectorModifiedDataBeforeFormat.rawData.conditions);

meanCapa = cell(1,length(conditionLength));
meanDifCapa = cell(1,length(conditionLength));
dimension = size(multiVectorModifiedDataBeforeFormat.multiVectorData{1},2);

if(dimension>1)
    for j = 1:conditionLength
        %まず, 平均を求める.
        meanCapa{j} = mean(multiVectorModifiedDataBeforeFormat.multiVectorData{j});
        %そこから平均を引いたものを創る.
        meanDifCapa{j} = multiVectorModifiedDataBeforeFormat.multiVectorData{j} -  meanCapa{j};
    end
end

allCapa = [];
for j = 1:conditionLength
    allCapa = [allCapa; meanDifCapa{j}]; %#ok
end

maximum = max(allCapa);
minimum = min(allCapa);
dif = maximum - minimum;
coeffi = dif ./ dif(1);

processedCapa = cell(1,length(conditionLength));

for j=1:conditionLength
    processedCapa{j} = multiVectorModifiedDataBeforeFormat.multiVectorData{j};
    if(dimension >1)
        for k = 2:dimension
            processedCapa{j}(:,k) = (meanDifCapa{j}(:,k) ./ coeffi(k)) + meanCapa{j}(k); %平均を足して戻してやる.
        end
    end
end

processedData = MultiVectorModifiedDataBeforeFormat(multiVectorModifiedDataBeforeFormat.rawData,processedCapa);
clear allCapa
end

