function [gasAverageValue, liquidAverageValue, isCalibrated] = resolveCapacitanceCalibration(date, correctCondition)
%RESOLVECAPACITANCECALIBRATION 静電容量の補正に使う気相100%・液相100%の基準値を求める.
%   correctWithCapacitanceBase / Two / Wave で共通に使う.
%   基準記録は次の順に探し, 最初に見つかったものを使う.
%     気相100%: G30_before_<液相条件> → CorrectConditions.gasOnlyReference (L0G30)
%     液相100%: <液相条件>G0 → CorrectConditions.liquidFallbackReference (L1G0)
%   2025/11/14・17のデータでは G30_before_ が L0.05 の分しかなく(中身は L0G30 と同一),
%   L0.05G0 も無いため, 代わりの記録が無いと全条件で補正がスキップされていた.
%   気相100%(約164 fF)と液相100%(約354〜357 fF)は液相流量・日によらずほぼ一定なので,
%   代わりの記録を使っても問題ない.
%
%   isCalibrated = false のとき, 基準値は使えないので呼び出し側で補正をスキップする.
    arguments
        date (1,1) string
        correctCondition (1,1) string
    end

    gasCandidates = [append(CorrectConditions.LiquidPureFlowPrefix, correctCondition), CorrectConditions.gasOnlyReference];
    liquidCandidates = [append(correctCondition, CorrectConditions.gasPreFlowSuffix), CorrectConditions.liquidFallbackReference];

    % 実験日ごとに基準を直接指定している場合はそれを優先する (CapacitanceReference.m を参照)
    ref = CapacitanceReference.forDate(date);
    if ~isempty(ref)
        if ~isnan(ref.gasValue)
            gasCandidates = strings(1, 0);
        elseif ref.gasRecord ~= ""
            gasCandidates = ref.gasRecord;
        end
        if ~isnan(ref.liquidValue)
            liquidCandidates = strings(1, 0);
        elseif ref.liquidRecord ~= ""
            liquidCandidates = ref.liquidRecord;
        end
    end

    if ~isempty(ref) && ~isnan(ref.gasValue)
        gasAverageValue = ref.gasValue;
    else
        gasAverageValue = readReferenceAverage(date, gasCandidates, "気相100%");
    end
    if ~isempty(ref) && ~isnan(ref.liquidValue)
        liquidAverageValue = ref.liquidValue;
    else
        liquidAverageValue = readReferenceAverage(date, liquidCandidates, "液相100%");
    end

    isCalibrated = ~isnan(gasAverageValue) && ~isnan(liquidAverageValue) ...
        && abs(liquidAverageValue - gasAverageValue) > 1e-15;
    if ~isCalibrated
        warning('%s の %s: 基準値が求められないため, 静電容量補正をスキップします.', date, correctCondition);
    end
end

function averageValue = readReferenceAverage(date, candidates, label)
    averageValue = NaN;
    for k = 1:numel(candidates)
        source = append(DataPath.path, date, "/", candidates(k), "/ALLDATA.csv");
        if exist(source, 'file') == 2
            if k > 1
                fprintf('%s の基準データとして %s を使用します (%s が見つからないため).\n', label, candidates(k), candidates(1));
            end
            tmp = readmatrix(source);
            averageValue = mean(rmoutliers(tmp(1:end, 2), 'ThresholdFactor', 10));
            return;
        end
    end
    warning('%sの基準データが見つかりません (%s).', label, strjoin(candidates, ", "));
end
