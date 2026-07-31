function y = affineMatchMeanStd(x, targetMean, targetStd)
%AFFINEMATCHMEANSTD 波形xの「形」を保ったまま平均・標準偏差だけを目標値に合わせる.
%   再構成波形 = (x - mean(x)) / std(x) * targetStd + targetMean
%   注意: この線形変換は std だけでなく diff(x) の std (=速さの指標) も同じ係数で
%   伸縮する. Pr_diffStd を独立に制御したい場合はこの関数だけでは不十分で,
%   findPrShapeDonor.m によるドナー選定と組み合わせて使うこと.
    arguments
        x (:,1) double
        targetMean (1,1) double
        targetStd (1,1) double
    end

    y = (x - mean(x)) / std(x) * targetStd + targetMean;
end
