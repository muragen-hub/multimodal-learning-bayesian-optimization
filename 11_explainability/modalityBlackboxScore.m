function scores = modalityBlackboxScore(T, allCap, allDiff, allFeat, forwardFcn, targetClassIdx)
%MODALITYBLACKBOXSCORE shapley() に渡すブラックボックス関数(モダリティ単位)
%   T: shapleyが生成するtable. 列 CapIdx/DiffIdx/FeatIdx を持ち,
%      各行は「CapWave/DiffWave/FeatureDataそれぞれをどのサンプルの値で置き換えるか」
%      を示す allCap/allDiff/allFeat への添字.
%   allCap, allDiff: 候補サンプル全体の波形データプール (cell array)
%   allFeat: 候補サンプル全体の特徴量データプール (double 行列, 行=サンプル)
%   forwardFcn: @(capBatch, diffBatch, featBatch) -> scoresMatrix
%               (行=サンプル, 列=クラス) を返すネットワークのforward関数.
%               ネットワークの型(dlnetwork/trainNetwork)ごとに呼び出し側で用意する.
%   targetClassIdx: 説明対象クラスの列番号

    arguments
        T table
        allCap (:,1) cell
        allDiff (:,1) cell
        allFeat double
        forwardFcn function_handle
        targetClassIdx {mustBePositive, mustBeInteger}
    end

    capBatch  = allCap(T.CapIdx);
    diffBatch = allDiff(T.DiffIdx);
    featBatch = allFeat(T.FeatIdx, :);

    scoresMatrix = forwardFcn(capBatch, diffBatch, featBatch);
    scores = scoresMatrix(:, targetClassIdx);
end
