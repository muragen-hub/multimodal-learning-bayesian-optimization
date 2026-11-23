%% summarizeStep1.m
% Step 1 (deepLearning_wave_2026_conditionCV.m) の結果を, 乱数の種 (1,2,3...) をまたいで集計する.
% 使い方 (リポジトリのルートで):  matlab -batch "summarizeStep1"
%   結果が別のフォルダにあるとき: matlab -batch "resultsRoot='/home/.../results/step1_conditionCV'; summarizeStep1"
% 読むもの : results/step1_conditionCV/<日時>_seed<種>/ の windows.csv と summary.txt
%            (summary.txt に quickTest=0 と書かれたものだけ. 同じ種が複数あれば新しい方)
% 出力     : results/step1_conditionCV/_summary_<ordered|shuffled>/ に summary_all.txt と各種CSV, confusion_pooled.png

clc; clearvars -except resultsRoot foldModeFilter; close all hidden;

% 集計する分割の方式: "ordered" (Step 1 の本番) か "shuffled" (Step 1b). 省略すると ordered.
% summary.txt に foldMode の記載が無い古い結果は ordered として扱う.
if ~exist("foldModeFilter", "var"), foldModeFilter = "ordered"; end
foldModeFilter = string(foldModeFilter);

% 結果が別のフォルダにあるときは, 先に resultsRoot = "/path/to/results/step1_conditionCV"; を指定する
if ~exist("resultsRoot", "var"), resultsRoot = fullfile("results", "step1_conditionCV"); end
root = string(resultsRoot);
outDir = fullfile(root, "_summary_" + foldModeFilter);
if ~isfolder(outDir), mkdir(outDir); end

%% 1. 結果の読み込み
folders = dir(root);
names = sort(string({folders([folders.isdir]).name}));
names = names(contains(names, "_seed"));
tables = {}; used = strings(0, 1); seedsSeen = [];
for i = 1:numel(names)
    sf = fullfile(root, names(i), "summary.txt");
    wf = fullfile(root, names(i), "windows.csv");
    if ~isfile(sf) || ~isfile(wf), continue; end
    head = readlines(sf);
    if ~contains(head(1), "quickTest=0"), continue; end   % 試し実行は除く
    thisMode = "ordered";
    if contains(head(1), "foldMode=shuffled"), thisMode = "shuffled"; end
    if thisMode ~= foldModeFilter, continue; end
    T = readtable(wf, "TextType", "string");
    s = T.Seed(1);
    k = find(seedsSeen == s);
    if isempty(k)
        tables{end+1} = T; used(end+1, 1) = names(i); seedsSeen(end+1) = s; %#ok<SAGROW>
    else
        tables{k} = T; used(k) = names(i);                  % 新しい方で置き換える
    end
end
assert(~isempty(tables), "本番の結果が見つかりません: %s", root);
A = vertcat(tables{:});
seeds = sort(unique(A.Seed))';
A.Correct = double(A.Correct);
regimes = sort(unique(A.TrueRegime))';
classes = sort(unique([A.TrueRegime; A.Predicted]))';
probVars = string(A.Properties.VariableNames(startsWith(A.Properties.VariableNames, "P_")));

fid = fopen(fullfile(outDir, "summary_all.txt"), "w", "n", "UTF-8");
emit(fid, "Step 1 集計: 種 = %s (%d種), 窓 = %d\n", mat2str(seeds), numel(seeds), height(A));
emit(fid, "使った結果:\n"); for i = 1:numel(used), emit(fid, "  %s\n", used(i)); end

%% 2. 全体と流動様式ごと (平均 ± 標準偏差. 標準偏差は種のあいだのばらつき)
emit(fid, "\n== 全体・流動様式ごとの正解率 [%%] (窓単位) ==\n");
allMask = true(height(A), 1);
byReg = nan(numel(seeds), numel(regimes));
for r = 1:numel(regimes)
    byReg(:, r) = accBySeed(A, A.TrueRegime == regimes(r), seeds);
end
emit(fid, "  全体            : %s\n", fmt(accBySeed(A, allMask, seeds)));
emit(fid, "  条件の重みをそろえた平均 (流動様式ごとの平均): %s\n", fmt(mean(byReg, 2)));
for r = 1:numel(regimes), emit(fid, "  %-15s : %s\n", regimes(r), fmt(byReg(:, r))); end

%% 3. 条件ごと
conds = unique(A.Condition, "stable");
rows = strings(0, 1); regOf = strings(0, 1); mu = []; sd = [];
for i = 1:numel(conds)
    m = A.Condition == conds(i);
    a = accBySeed(A, m, seeds);
    rows(end+1, 1) = conds(i); regOf(end+1, 1) = A.TrueRegime(find(m, 1)); %#ok<SAGROW>
    mu(end+1, 1) = mean(a, "omitnan"); sd(end+1, 1) = std(a, 0, "omitnan"); %#ok<SAGROW>
end
perCond = table(rows, regOf, mu, sd, 'VariableNames', ["Condition", "TrueRegime", "MeanAccuracy", "StdAccuracy"]);
perCond = sortrows(perCond, ["TrueRegime", "Condition"]);
writetable(perCond, fullfile(outDir, "perCondition_meanstd.csv"));
emit(fid, "\n== 条件ごとの正解率 [%%] (平均 ± 標準偏差) ==\n");
for i = 1:height(perCond)
    emit(fid, "  %-10s %-11s %5.1f ± %4.1f\n", perCond.Condition(i), perCond.TrueRegime(i), perCond.MeanAccuracy(i), perCond.StdAccuracy(i));
end

%% 4. 条件ごとの予測先 (どのクラスに間違えたか. 全種の窓をまとめて)
dist = zeros(numel(conds), numel(classes));
for i = 1:numel(conds)
    m = A.Condition == conds(i);
    for c = 1:numel(classes), dist(i, c) = 100 * mean(A.Predicted(m) == classes(c)); end
end
distT = array2table(dist, 'VariableNames', "Pred_" + classes);
distT = [table(conds, 'VariableNames', "Condition"), distT];
writetable(distT, fullfile(outDir, "predictedShareByCondition.csv"));
emit(fid, "\n== 正解率が90%%未満の条件の予測先 [%%] ==\n");
for i = 1:numel(conds)
    if perCond.MeanAccuracy(perCond.Condition == conds(i)) < 90
        emit(fid, "  %-10s (%s):", conds(i), A.TrueRegime(find(A.Condition == conds(i), 1)));
        for c = 1:numel(classes), emit(fid, " %s=%.0f", classes(c), dist(i, c)); end
        emit(fid, "\n");
    end
end

%% 5. 層状流の窓を「液の橋あり/届きかけ/なし」で分けた結果 (この研究の中心)
S = A(A.TrueRegime == "Stratified", :);
bridgeClasses = ["bridge", "partial", "none"];
emit(fid, "\n== 層状流の窓: 液の橋の有無別 ==\n");
emit(fid, "  %-8s %8s %20s %12s %12s\n", "区分", "窓/種", "正解率[%]", "平均P(Slug)", "平均P(Strat)");
bRows = {};
for b = bridgeClasses
    m = S.BridgeClass == b;
    if ~any(m), continue; end
    a = accBySeed(S, m, seeds);
    nPer = sum(m) / numel(seeds);
    pSlug = mean(S.P_Slug(m)); pStrat = mean(S.P_Stratified(m));
    emit(fid, "  %-8s %8.0f %20s %12.3f %12.3f\n", b, nPer, fmt(a), pSlug, pStrat);
    bRows{end+1} = table(b, nPer, mean(a, "omitnan"), std(a, 0, "omitnan"), pSlug, pStrat, ...
        'VariableNames', ["BridgeClass", "WindowsPerSeed", "MeanAccuracy", "StdAccuracy", "MeanP_Slug", "MeanP_Stratified"]); %#ok<AGROW>
end
bTab = vertcat(bRows{:});
writetable(bTab, fullfile(outDir, "stratifiedByBridge_meanstd.csv"));
emit(fid, "  (窓の中で静電容量が311 fF以上の割合) と P(Slug) の相関 (層状流の窓): r = %.3f\n", localCorr(S.BridgeFraction, S.P_Slug));
emit(fid, "\n  層状流の窓の予測先 [%%] (区分ごと):\n");
for b = bridgeClasses
    m = S.BridgeClass == b;
    if ~any(m), continue; end
    emit(fid, "    %-8s:", b);
    for c = 1:numel(classes), emit(fid, " %s=%.1f", classes(c), 100 * mean(S.Predicted(m) == classes(c))); end
    emit(fid, "\n");
end
% 層状流の各条件で, 液の橋を含む窓の割合 (層状流の運転点ごとの違い)
emit(fid, "\n  層状流の各条件で液の橋を含む窓の割合 [%%]:\n");
for cnd = unique(S.Condition, "stable")'
    m = S.Condition == cnd;
    emit(fid, "    %-10s bridge=%.0f  partial=%.0f  none=%.0f\n", cnd, ...
        100 * mean(S.BridgeClass(m) == "bridge"), 100 * mean(S.BridgeClass(m) == "partial"), 100 * mean(S.BridgeClass(m) == "none"));
end

%% 6. 混同行列 (全種の窓をまとめた, 行方向に正規化)
cm = zeros(numel(regimes), numel(classes));
for r = 1:numel(regimes)
    m = A.TrueRegime == regimes(r);
    for c = 1:numel(classes), cm(r, c) = 100 * mean(A.Predicted(m) == classes(c)); end
end
cmT = array2table(cm, 'VariableNames', "Pred_" + classes, "RowNames", cellstr(regimes));
writetable(cmT, fullfile(outDir, "confusion_pooled.csv"), "WriteRowNames", true);
emit(fid, "\n== 混同行列 [%%] (行 = 正解, 列 = 予測) ==\n");
emit(fid, "  %-12s", ""); for c = 1:numel(classes), emit(fid, " %10s", classes(c)); end; emit(fid, "\n");
for r = 1:numel(regimes)
    emit(fid, "  %-12s", regimes(r)); for c = 1:numel(classes), emit(fid, " %10.1f", cm(r, c)); end; emit(fid, "\n");
end
fig = figure("Visible", "off");
confusionchart(categorical(A.TrueRegime, classes), categorical(A.Predicted, classes), "RowSummary", "row-normalized");
title("Step 1 条件単位の交差検証 (" + numel(seeds) + "種をまとめた)");
exportgraphics(fig, fullfile(outDir, "confusion_pooled.png"));

fclose(fid);
type(fullfile(outDir, "summary_all.txt"));
fprintf("\n保存しました: %s\n", outDir);

%% ---- ローカル関数 ----
function a = accBySeed(A, mask, seeds)
    % 種ごとの正解率 [%] (その種に該当する窓が無ければ NaN)
    a = nan(numel(seeds), 1);
    for j = 1:numel(seeds)
        m = mask & A.Seed == seeds(j);
        if any(m), a(j) = 100 * mean(A.Correct(m)); end
    end
end

function r = localCorr(x, y)
    % 相関係数 (統計ツールボックスが無くても動くように corrcoef を使う)
    c = corrcoef(x, y);
    r = c(1, 2);
end

function s = fmt(a)
    % 平均 ± 標準偏差 (種のあいだ) と, 種ごとの値
    parts = strings(1, numel(a));
    for j = 1:numel(a), parts(j) = sprintf("%.1f", a(j)); end
    s = sprintf("%5.1f ± %4.1f  (種ごと: %s)", mean(a, "omitnan"), std(a, 0, "omitnan"), strjoin(parts, ", "));
end

function emit(fid, varargin)
    s = sprintf(varargin{:});
    fprintf("%s", s);
    fprintf(fid, "%s", s);
end
