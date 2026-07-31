function explainer = computeShapleyPhysicalStats(allVF, allPr, forwardFcn, targetClassIdx, bgIdx, queryIdx, nameAndVar)
%COMPUTESHAPLEYPHYSICALSTATS VF_mean/VF_std/Pr_mean/Pr_std/Pr_diffStdの5特徴量でShapley値を計算する.
%   deepLearning_wave_multimodalClassification.mlx の学習済みモデルを対象とし,
%   「差圧と静電容量の組み合わせがなぜ流動様式判別に効果的か」という仮説
%   (VF→ボイド率, Pr→運動エネルギー変化)を物理的統計量の単位で検証するための関数.
%
%   allVF, allPr: 背景/形状ドナープール全体の波形データ(cell配列, N×1)
%   forwardFcn: @(vfBatch, prBatch) -> scoresMatrix(行=サンプル, 列=クラス)
%               実データでの結線例:
%               forwardFcn = @(vfBatch, prBatch) ...
%                   extractdata(predict(net, wavesToCTB(vfBatch, prBatch), Outputs=["softmax"]))';
%   targetClassIdx: 説明対象クラスの列番号
%   bgIdx: 背景(参照)サンプルの添字ベクトル(allVF/allPrへの添字)
%   queryIdx: 説明したいクエリサンプルの添字(スカラー)
%
%   explainer.Shapley.Value の並びはbackgroundTableの列順
%   [VF_mean, VF_std, Pr_mean, Pr_std, Pr_diffStd] に対応する.
    arguments
        allVF (:,1) cell
        allPr (:,1) cell
        forwardFcn function_handle
        targetClassIdx {mustBePositive, mustBeInteger}
        bgIdx (1,:) {mustBePositive, mustBeInteger}
        queryIdx (1,1) {mustBePositive, mustBeInteger}
        nameAndVar.UseParallel (1,1) logical = false
    end

    prShapeR = precomputePrShapeRatios(allPr);

    bgStats = cell(numel(bgIdx), 1);
    for i = 1:numel(bgIdx)
        bgStats{i} = extractPhysicalStats(allVF{bgIdx(i)}(:), allPr{bgIdx(i)}(:));
    end
    backgroundTable = vertcat(bgStats{:});

    queryTable = extractPhysicalStats(allVF{queryIdx}(:), allPr{queryIdx}(:));

    blackbox = @(T) physicalStatsBlackboxScore(T, allVF, allPr, prShapeR, forwardFcn, targetClassIdx);

    explainer = shapley(blackbox, backgroundTable, ...
        'QueryPoints', queryTable, ...
        'NumObservationsToSample', 'all', ...
        'UseParallel', nameAndVar.UseParallel);
end
