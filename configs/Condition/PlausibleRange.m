classdef PlausibleRange
    %PLAUSIBLERANGE 計測値として物理的にありえる範囲. この範囲の外だけを外れ値として除く.
    %   以前は rmoutliers (中央値からの距離) で外れ値を除いていたが,
    %   層状流の記録に混ざる液の橋 (静電容量が約230 fF -> 約325 fF に跳ねる) や
    %   スラグ通過時の差圧のピークまで外れ値として消していた
    %   (2025年の L0.05 で 5〜21%, 2026年の L0.3G3 で約11%, L1G20 で約13%).
    %   遷移を調べるにはこれらを残す必要があるので, 明らかな異常値 (Cメータのエラー値など) だけを除く.
    %
    %   範囲の根拠 (2025/11/14・17, 2026/11/20 の全条件で確認):
    %     静電容量: 気相100% 約148〜164 fF, 液相100% 約329〜357 fF → 100〜400 fF の外はありえない
    %               (2025年の一部の記録には -1e+?? のエラー値が約0.2% 含まれる)
    %     差圧    : 実測は -4〜205 kPa. 圧力計の測定範囲 (-100〜300 kPa) から -100〜400 kPa の外はありえない

    properties (Constant)
        capacitanceMin = 100e-15;   % [F]
        capacitanceMax = 400e-15;   % [F]
        diffPressureMin = -100;     % [kPa]
        diffPressureMax = 400;      % [kPa]
    end

    methods (Static)
        function isOut = capacitanceOutliers(capacitance)
            isOut = ~isfinite(capacitance) | capacitance < PlausibleRange.capacitanceMin | capacitance > PlausibleRange.capacitanceMax;
        end

        function isOut = diffPressureOutliers(diffPressure)
            isOut = ~isfinite(diffPressure) | diffPressure < PlausibleRange.diffPressureMin | diffPressure > PlausibleRange.diffPressureMax;
        end
    end
end
