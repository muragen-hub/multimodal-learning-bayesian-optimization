function scores = physicalStatsBlackboxScore(T, allVF, allPr, prShapeR, forwardFcn, targetClassIdx)
%PHYSICALSTATSBLACKBOXSCORE shapley() に渡すブラックボックス関数(物理統計量ベース).
%   T: 列 VF_mean, VF_std, Pr_mean, Pr_std, Pr_diffStd を持つtable.
%      各行は「この5統計量を持つ合成波形ペア」を表す(値そのものであり, プールへの
%      添字ではない点がchannelBlackboxScore.mと異なる).
%
%   再構成方針(1行につき1つの背景サンプルを「形状ドナー」として選ぶ):
%     1. Pr_diffStd/Pr_std の目標比に最も近いrを持つ背景サンプルを最近傍で選ぶ
%        (findPrShapeDonor.m). このサンプルのVF波形・Pr波形の両方を
%        アフィン変換のベースとして流用する(簡略化: VF側の形状はPr由来の
%        ドナーにそのまま従う).
%     2. そのドナー波形をaffineMatchMeanStd.mで目標のmean/stdに合わせる.
%        (Pr_diffStdは完全一致は保証されないが, 目標比に近いドナーを選んでいるため
%        近似として妥当)
%
%   allVF, allPr: 背景/形状ドナープール全体の波形データ(cell配列)
%   prShapeR: precomputePrShapeRatios(allPr) の結果
%   forwardFcn: @(vfBatch, prBatch) -> scoresMatrix(行=サンプル, 列=クラス)
%   targetClassIdx: 説明対象クラスの列番号
    arguments
        T table
        allVF (:,1) cell
        allPr (:,1) cell
        prShapeR (:,1) double
        forwardFcn function_handle
        targetClassIdx {mustBePositive, mustBeInteger}
    end

    n = height(T);
    vfBatch = cell(n,1);
    prBatch = cell(n,1);
    for i = 1:n
        donorIdx = findPrShapeDonor(prShapeR, T.Pr_diffStd(i), T.Pr_std(i));
        vfBatch{i} = affineMatchMeanStd(allVF{donorIdx}(:), T.VF_mean(i), T.VF_std(i));
        prBatch{i} = affineMatchMeanStd(allPr{donorIdx}(:), T.Pr_mean(i), T.Pr_std(i));
    end

    scoresMatrix = forwardFcn(vfBatch, prBatch);
    scores = scoresMatrix(:, targetClassIdx);
end
