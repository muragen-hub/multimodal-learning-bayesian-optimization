function scores = channelBlackboxScore(T, allVF, allPr, forwardFcn, targetClassIdx)
%CHANNELBLACKBOXSCORE shapley() に渡すブラックボックス関数(チャンネル単位).
%   T: shapleyが生成するtable. 列 VFIdx/PrIdx を持ち, 各行は
%      「VF波形・Pr波形それぞれをどのサンプルの値で丸ごと置き換えるか」を示す
%      allVF/allPr への添字.
%   allVF, allPr: 候補サンプル全体の波形データプール (cell array, 各要素は数値ベクトル)
%   forwardFcn: @(vfBatch, prBatch) -> scoresMatrix(行=サンプル, 列=クラス)
%   targetClassIdx: 説明対象クラスの列番号
    arguments
        T table
        allVF (:,1) cell
        allPr (:,1) cell
        forwardFcn function_handle
        targetClassIdx {mustBePositive, mustBeInteger}
    end

    vfBatch = allVF(T.VFIdx);
    prBatch = allPr(T.PrIdx);

    scoresMatrix = forwardFcn(vfBatch, prBatch);
    scores = scoresMatrix(:, targetClassIdx);
end
