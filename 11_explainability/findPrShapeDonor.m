function donorIdx = findPrShapeDonor(prShapeR, targetDiffStd, targetStd)
%FINDPRSHAPEDONOR Pr_diffStd/Pr_std比が目標に最も近い背景サンプルを最近傍で選ぶ.
%   affine変換だけでは Pr_std を目標値に合わせた時点で Pr_diffStd は背景サンプルが
%   元々持っていた diffStd/std比に従って決まってしまうため, まず「速さ」の形状が
%   近いサンプルをドナーとして選んでからaffine変換で水準(mean/std)を合わせる,
%   という2段階の再構成が必要(affineMatchMeanStd.m と組み合わせて使う).
%
%   prShapeR: precomputePrShapeRatios.m で事前計算した背景プール全体のr値
%   targetDiffStd, targetStd: 目標とするPr_diffStd, Pr_std
%   donorIdx: prShapeR(したがって元の背景プール)へのドンサンプル添字
    arguments
        prShapeR (:,1) double
        targetDiffStd (1,1) double
        targetStd (1,1) double
    end

    targetR = targetDiffStd / targetStd;
    [~, donorIdx] = min(abs(prShapeR - targetR));
end
