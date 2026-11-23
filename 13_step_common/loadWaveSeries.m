function series = loadWaveSeries(date, conds, labs, corr, measuredFreq, dpHoldSamples)
%LOADWAVESERIES 1日分の ALLDATA.csv を読み込み, 前処理 (100 Hz への再サンプリング, ボイド率への換算) をして返す.
%   series(i).cond / regime / vf / dp / day. vf はボイド率, dp は差圧 [kPa], 長さをそろえ NaN を除いてある.
%   dpHoldSamples > 1 のとき, 差圧をその点数ごとに保持する (階段状にする).
%     2025年のデータは差圧が約20 Hz で記録され, 100 Hz に保持して並べてあるため, 2026年の差圧
%     (本当の100 Hz) を 5点保持にすると 2025年と同じ時間分解能になる.
    arguments
        date (1,1) string
        conds (1,:) string
        labs (1,:) string
        corr (1,:) string
        measuredFreq (1,1) double
        dpHoldSamples (1,1) double = 0
    end

    dc = RawDataCreatorWave();
    vfRaw = dc.createVF(date, measuredFreq, conds, labs, true, corr);
    prRaw = dc.createPr(date, measuredFreq, conds, labs, true, corr);
    rawAll = RawAllDataBeforeFormatWave([vfRaw, prRaw]);
    pp = PreProcessorBeforeFormatWave({@intervalUniformerWave, @correctWithCapacitanceBaseWave});
    vf = pp.process(vfRaw, rawAll);
    pr = pp.process(prRaw, rawAll);

    series = struct("cond", {}, "regime", {}, "vf", {}, "dp", {}, "day", {});
    for i = 1:numel(conds)
        v = vf.modifiedRawDataWave(i).WaveDataCell{1};
        p = pr.modifiedRawDataWave(i).WaveDataCell{1};
        n = min(numel(v), numel(p));
        v = v(1:n); p = p(1:n);
        ok = ~isnan(v) & ~isnan(p);
        v = v(ok); p = p(ok);
        if dpHoldSamples > 1
            m = numel(p);
            p = p(floor((0:m - 1)' / dpHoldSamples) * dpHoldSamples + 1);
        end
        series(i).cond = string(vf.modifiedRawDataWave(i).conditions{1});
        series(i).regime = string(vf.modifiedRawDataWave(i).FlowRegimeLabel);
        series(i).vf = v(:);
        series(i).dp = p(:);
        series(i).day = date;
        assert(series(i).cond == conds(i), "条件の並びがずれています: %s", series(i).cond);
    end
end
