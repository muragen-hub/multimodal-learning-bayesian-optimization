function stats = extractPhysicalStats(vf, pr)
%EXTRACTPHYSICALSTATS 1サンプル分のVF波形・Pr波形から物理的統計量5つを抽出する.
%   vf, pr: 数値ベクトル(同じ長さ, dataWidth点)
%   stats: table (1行), 列 = VF_mean, VF_std, Pr_mean, Pr_std, Pr_diffStd
%
%   VF_mean    平均ボイド率            (静電容量 → ボイド率 仮説の主指標)
%   VF_std     ボイド率の時間変動      (相分布の間欠性)
%   Pr_mean    平均差圧                (対照指標・ベースライン)
%   Pr_std     差圧変動の振幅          (差圧 → 運動エネルギー変化 仮説の主指標①)
%   Pr_diffStd std(diff(Pr)), 差圧変化率の変動 (同仮説の主指標②, Pr_stdより直接的)
    arguments
        vf (:,1) double
        pr (:,1) double
    end

    dPr = diff(pr(:));
    stats = table(mean(vf), std(vf), mean(pr), std(pr), std(dPr), ...
        'VariableNames', {'VF_mean','VF_std','Pr_mean','Pr_std','Pr_diffStd'});
end
