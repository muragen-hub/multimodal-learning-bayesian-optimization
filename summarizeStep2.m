%% summarizeStep2.m
% Step 2 (deepLearning_wave_crossYear.m) の結果を, 乱数の種をまたいで集計する.
% 使い方 (リポジトリのルートで):
%   matlab -batch "summarizeStep2"                                   % 既定: 標準化=trainStats, 検証=none, 入力=[1 2]
%   matlab -batch "stdFilter='ownYear'; summarizeStep2"              % 標準化を変える
%   matlab -batch "chFilter='1'; summarizeStep2"                     % ボイド率のみ (channels=1)
%   matlab -batch "valFilter='conditionHoldout'; summarizeStep2"     % 検証あり
%   結果が別のフォルダにあるとき: resultsRoot='/home/.../results/step2_crossYear' も指定する
% 読むもの : results/step2_crossYear/<日時>_seed<種>_<設定>/ の windows.csv と summary.txt (quickTest=0 のものだけ.
%            summary.txt に 検証= の記載が無い古い結果は conditionHoldout として扱う. 同じ種が複数あれば新しい方)
% 出力     : results/step2_crossYear/_summary_<設定>/ に summary_all.txt と perCondition_meanstd.csv

clc; clearvars -except resultsRoot stdFilter valFilter chFilter; close all hidden;
if ~exist("resultsRoot", "var"), resultsRoot = fullfile("results", "step2_crossYear"); end
if ~exist("stdFilter", "var"), stdFilter = "trainStats"; end
if ~exist("valFilter", "var"), valFilter = "none"; end
if ~exist("chFilter", "var"), chFilter = "[1 2]"; end
root = string(resultsRoot); stdFilter = string(stdFilter); valFilter = string(valFilter); chFilter = string(chFilter);
tag = stdFilter + "_val" + valFilter + "_ch" + regexprep(chFilter, "[^0-9]", "");
outDir = fullfile(root, "_summary_" + tag);
if ~isfolder(outDir), mkdir(outDir); end

%% 1. 結果の読み込み (設定が一致するものだけ)
folders = dir(root);
names = sort(string({folders([folders.isdir]).name}));
names = names(contains(names, "_seed"));
tables = {}; used = strings(0, 1); seedsSeen = [];
for i = 1:numel(names)
    sf = fullfile(root, names(i), "summary.txt");
    wf = fullfile(root, names(i), "windows.csv");
    if ~isfile(sf) || ~isfile(wf), continue; end
    head = readlines(sf); head = head(1);
    if ~contains(head, "quickTest=0"), continue; end
    tk = regexp(head, '標準化=(\w+)', 'tokens', 'once'); if isempty(tk), continue; end
    thisStd = string(tk{1});
    tk = regexp(head, '検証=(\w+)', 'tokens', 'once');
    if isempty(tk), thisVal = "conditionHoldout"; else, thisVal = string(tk{1}); end
    tk = regexp(head, '使う信号=(\[[^\]]*\]|\d+)', 'tokens', 'once'); if isempty(tk), continue; end
    thisCh = string(tk{1});
    if thisStd ~= stdFilter || thisVal ~= valFilter || thisCh ~= chFilter, continue; end
    T = readtable(wf, "TextType", "string");
    s = T.Seed(1);
    k = find(seedsSeen == s);
    if isempty(k)
        tables{end+1} = T; used(end+1, 1) = names(i); seedsSeen(end+1) = s; %#ok<SAGROW>
    else
        tables{k} = T; used(k) = names(i);
    end
end
assert(~isempty(tables), "設定に合う本番の結果が見つかりません: %s (標準化=%s, 検証=%s, 入力=%s)", root, stdFilter, valFilter, chFilter);
A = vertcat(tables{:});
A.Correct = double(A.Correct);
seeds = sort(unique(A.Seed))';
exps = unique(A.Exp, "stable")';
classes = sort(unique([A.TrueRegime; A.Predicted]))';

fid = fopen(fullfile(outDir, "summary_all.txt"), "w", "n", "UTF-8");
emit(fid, "Step 2 集計: 標準化=%s, 検証=%s, 入力=%s, 種 = %s (%d種), 窓 = %d\n", stdFilter, valFilter, chFilter, mat2str(seeds), numel(seeds), height(A));
emit(fid, "使った結果:\n"); for i = 1:numel(used), emit(fid, "  %s\n", used(i)); end

%% 2. 実験ごとの全体・クラスごとの正解率 (平均 ± 標準偏差. 標準偏差は種のあいだのばらつき)
for e = exps
    Te = A(A.Exp == e, :);
    emit(fid, "\n== %s ==\n", e);
    emit(fid, "  全体            : %s\n", fmt(accBySeed(Te, true(height(Te), 1), seeds)));
    for c = sort(unique(Te.TrueRegime))'
        emit(fid, "  %-15s : %s\n", c, fmt(accBySeed(Te, Te.TrueRegime == c, seeds)));
    end
    for sv = [true false]
        m = Te.SeenCondition == sv;
        if any(m)
            if sv, lbl = "同じ名目流量が学習にもあった条件"; else, lbl = "同じ名目流量が学習に無かった条件"; end
            nc = numel(unique(Te.Condition(m) + "@" + Te.TestSet(m)));
            emit(fid, "  %s (%d条件): %s\n", lbl, nc, fmt(accBySeed(Te, m, seeds)));
        end
    end
end

%% 3. 条件ごと (平均 ± 標準偏差) と予測先
rowsE = strings(0, 1); rowsD = strings(0, 1); rowsC = strings(0, 1); rowsR = strings(0, 1);
mu = []; sd = []; share = zeros(0, numel(classes));
for e = exps
    Te = A(A.Exp == e, :);
    keys = unique(Te.TestSet + "@" + Te.Condition, "stable");
    emit(fid, "\n== %s: 条件ごとの正解率 [%%] (平均 ± 標準偏差) と予測先 [%%] ==\n", e);
    for k = 1:numel(keys)
        parts = split(keys(k), "@");
        m = Te.TestSet == parts(1) & Te.Condition == parts(2);
        a = accBySeed(Te, m, seeds);
        sh = zeros(1, numel(classes));
        for c = 1:numel(classes), sh(c) = 100 * mean(Te.Predicted(m) == classes(c)); end
        reg = Te.TrueRegime(find(m, 1));
        rowsE(end+1, 1) = e; rowsD(end+1, 1) = parts(1); rowsC(end+1, 1) = parts(2); rowsR(end+1, 1) = reg; %#ok<SAGROW>
        mu(end+1, 1) = mean(a, "omitnan"); sd(end+1, 1) = std(a, 0, "omitnan"); share(end+1, :) = sh; %#ok<SAGROW>
        pr = strings(1, numel(classes)); for c = 1:numel(classes), pr(c) = sprintf("%s=%.0f", classes(c), sh(c)); end
        emit(fid, "  %s %-9s %-10s %5.1f ± %4.1f   %s\n", parts(1), parts(2), reg, mu(end), sd(end), strjoin(pr, " "));
    end
end
perCond = table(rowsE, rowsD, rowsC, rowsR, mu, sd, 'VariableNames', {'Exp', 'TestSet', 'Condition', 'TrueRegime', 'MeanAccuracy', 'StdAccuracy'});
shareT = array2table(share, 'VariableNames', cellstr("Pred_" + classes));
writetable([perCond, shareT], fullfile(outDir, "perCondition_meanstd.csv"));

%% 4. 混同行列 (全種をまとめた, 行方向に正規化)
for e = exps
    Te = A(A.Exp == e, :);
    regimes = sort(unique(Te.TrueRegime))';
    emit(fid, "\n== %s: 混同行列 [%%] (行 = 正解, 列 = 予測) ==\n", e);
    emit(fid, "  %-12s", ""); for c = 1:numel(classes), emit(fid, " %10s", classes(c)); end; emit(fid, "\n");
    for r = regimes
        m = Te.TrueRegime == r;
        emit(fid, "  %-12s", r); for c = 1:numel(classes), emit(fid, " %10.1f", 100 * mean(Te.Predicted(m) == classes(c))); end; emit(fid, "\n");
    end
end
fclose(fid);
type(fullfile(outDir, "summary_all.txt"));
fprintf("\n保存しました: %s\n", outDir);

%% ---- ローカル関数 ----
function a = accBySeed(A, mask, seeds)
    a = nan(numel(seeds), 1);
    for j = 1:numel(seeds)
        m = mask & A.Seed == seeds(j);
        if any(m), a(j) = 100 * mean(A.Correct(m)); end
    end
end

function s = fmt(a)
    parts = strings(1, numel(a));
    for j = 1:numel(a), parts(j) = sprintf("%.1f", a(j)); end
    s = sprintf("%5.1f ± %4.1f  (種ごと: %s)", mean(a, "omitnan"), std(a, 0, "omitnan"), strjoin(parts, ", "));
end

function emit(fid, varargin)
    s = sprintf(varargin{:});
    fprintf("%s", s);
    fprintf(fid, "%s", s);
end
