function r = precomputePrShapeRatios(allPr)
%PRECOMPUTEPRSHAPERATIOS 背景プール全サンプルについて形状(速さ)診断比 r = std(diff(Pr))/std(Pr) を事前計算する.
%   r はスケール非依存(affine変換で不変)な形状パラメータ. Pr_diffStd を独立に
%   制御するための最近傍ドナー選定(findPrShapeDonor.m)で使う.
    arguments
        allPr (:,1) cell
    end

    n = numel(allPr);
    r = zeros(n,1);
    for i = 1:n
        prI = allPr{i}(:);
        r(i) = std(diff(prI)) / std(prI);
    end
end
