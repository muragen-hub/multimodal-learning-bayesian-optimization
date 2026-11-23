classdef CapacitanceReference
    %CAPACITANCEREFERENCE 実験日ごとに, 静電容量の基準 (気相100%, 液相100%) を直接指定する.
    %   通常は resolveCapacitanceCalibration.m が G30_before_<液相条件> や <液相条件>G0 の記録を探すが,
    %   その名前の記録が無い日はここで指定する. 指定が無い日は従来どおり記録を探す.
    %
    %   2026/11/20:
    %     液相100%: test002 (液相のみ, 約 L2.6G0, 約329 fF) の記録を使う
    %     気相100%: 気相のみの記録が無い. 全記録の最小値付近 (約148 fF) を暫定値とする.
    %               本当の値はこれ以下なので, ボイド率はやや大きめに出る.
    %               次回の実験で L0G30 を記録したら, gasRecord に置き換えること.

    methods (Static)
        function ref = forDate(date)
            % ref.gasRecord / ref.liquidRecord : 基準に使う記録名 ("" なら使わない)
            % ref.gasValue / ref.liquidValue   : 基準値 [F] (NaN なら使わない). 記録名より優先
            % 指定が無い日は空 ([]) を返す
            arguments
                date (1,1) string
            end
            ref = [];
            switch CapacitanceReference.normalizeDate(date)
                case "20261120"
                    ref.gasRecord = "";
                    ref.gasValue = 148e-15;      % 暫定 (気相のみの記録が無いため)
                    ref.liquidRecord = "test002";
                    ref.liquidValue = NaN;
            end
        end

        function d = normalizeDate(date)
            % "261120" と "20261120" を同じ日として扱う
            arguments
                date (1,1) string
            end
            c = char(date);
            if numel(c) == 6
                d = "20" + string(c);
            else
                d = string(c);
            end
        end
    end
end
