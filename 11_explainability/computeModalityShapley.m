function explainer = computeModalityShapley(allCap, allDiff, allFeat, forwardFcn, targetClassIdx, bgIdx, queryIdx, nameAndVar)
%COMPUTEMODALITYSHAPLEY CapWave/DiffWave/FeatureData の3モダリティ単位でシャープレイ値を計算する
%   1件のクエリサンプル(queryIdx)の予測に対して、3つのモダリティそれぞれが
%   どれだけ寄与したかを、背景サンプル(bgIdx)を参照点として計算する.
%   特徴量(モダリティ)は3つのみのため、shapleyは厳密な全列挙(2^3=8通り)で計算される.
%
%   allCap, allDiff, allFeat: 全候補サンプルのデータプール(train/testを跨いでも良い).
%                             queryIdx, bgIdx はこのプールへの添字.
%   forwardFcn: @(capBatch, diffBatch, featBatch) -> scoresMatrix(行=サンプル,列=クラス)
%   targetClassIdx: 寄与度を説明する対象クラスの列番号
%   bgIdx: 背景(参照)サンプルの添字ベクトル
%   queryIdx: 説明したいクエリサンプルの添字(スカラー)

    arguments
        allCap (:,1) cell
        allDiff (:,1) cell
        allFeat double
        forwardFcn function_handle
        targetClassIdx {mustBePositive, mustBeInteger}
        bgIdx (1,:) {mustBePositive, mustBeInteger}
        queryIdx (1,1) {mustBePositive, mustBeInteger}
        nameAndVar.UseParallel (1,1) logical = false
    end

    bgIdxCol = bgIdx(:);
    backgroundTable = table(bgIdxCol, bgIdxCol, bgIdxCol, ...
        'VariableNames', {'CapIdx','DiffIdx','FeatIdx'});
    queryTable = table(queryIdx, queryIdx, queryIdx, ...
        'VariableNames', {'CapIdx','DiffIdx','FeatIdx'});

    blackbox = @(T) modalityBlackboxScore(T, allCap, allDiff, allFeat, forwardFcn, targetClassIdx);

    explainer = shapley(blackbox, backgroundTable, ...
        'QueryPoints', queryTable, ...
        'NumObservationsToSample', 'all', ...
        'UseParallel', nameAndVar.UseParallel);
end
