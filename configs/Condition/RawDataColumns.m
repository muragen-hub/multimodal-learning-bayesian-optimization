classdef RawDataColumns
    %RAWDATACOLUMNS ALLDATA.csv の列の並び (1始まり) を実験日ごとに返す.
    %   2025年までと2026年以降で圧力計の列が違うので, 差圧の計算に使う列をここで切り替える.
    %     2025年 (例: 20251114): 6列目 = 上流圧力, 8列目 = スロート圧力
    %     2026年 (例: 261120)  : 6列目 = 上流圧力, 7列目 = スロート圧力, 8列目 = 経過時間[s]
    %   2026年のファイルにも8列目があるため, 列数だけで判断すると
    %   「上流圧力 - 経過時間」を差圧として使ってしまう. 必ず日付で判断する.
    %
    %   使い方: c = RawDataColumns.forDate("261120"); dp = tmp(:, c.upstreamPressure) - tmp(:, c.throatPressure);

    methods (Static)
        function c = forDate(date)
            arguments
                date (1,1) string
            end
            year = RawDataColumns.yearOf(date);

            c.time = 1;
            c.capacitance = 2;
            c.liquidFlowRate = 4;
            c.gasFlowRate = 5;
            c.upstreamPressure = 6;
            if year >= 2026
                c.throatPressure = 7;
            else
                c.throatPressure = 8;
            end
        end

        function year = yearOf(date)
            % "20251114" (yyyymmdd) と "261120" (yymmdd) の両方に対応する
            arguments
                date (1,1) string
            end
            d = char(date);
            if numel(d) == 8
                year = str2double(d(1:4));
            elseif numel(d) == 6
                year = 2000 + str2double(d(1:2));
            else
                error("RawDataColumns:badDate", "日付 %s の形式が分かりません (yyyymmdd か yymmdd).", date);
            end
            if isnan(year)
                error("RawDataColumns:badDate", "日付 %s から年を読み取れません.", date);
            end
        end
    end
end
