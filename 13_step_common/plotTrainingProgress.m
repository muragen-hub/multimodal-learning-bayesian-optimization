function plotTrainingProgress(history, titleText, pngFile)
%PLOTTRAININGPROGRESS 学習の進行の図 (MATLAB の「学習の進行状況」と同じ形) を PNG に保存する.
%   青い線: 学習の正解率 (ミニバッチごと. 濃い線は移動平均), 黒い点: 検証の正解率 (エポックごと),
%   赤い四角: 監視用データ (テストデータ) の正解率. 赤い四角は表示だけで, 学習の判断には使っていない.
%   灰色の帯: エポックの区切り.
    fig = figure("Visible", "off", "Position", [100 100 900 520]);
    ax = axes(fig); hold(ax, "on");
    it = 1:numel(history.trainAcc);
    e0 = [0, history.epochIter];
    for k = 1:numel(history.epochIter)
        if mod(k, 2) == 0
            patch(ax, [e0(k) e0(k + 1) e0(k + 1) e0(k)], [0 0 100 100], [0.9 0.9 0.9], "EdgeColor", "none", "FaceAlpha", 0.6, "HandleVisibility", "off");
        end
    end
    plot(ax, it, history.trainAcc, "Color", [0.55 0.75 0.95], "LineWidth", 0.5, "DisplayName", "学習 (ミニバッチ)");
    plot(ax, it, movmean(history.trainAcc, min(200, max(1, floor(numel(it) / 5)))), "Color", [0.05 0.35 0.7], "LineWidth", 1.6, "DisplayName", "学習 (移動平均)");
    if any(~isnan(history.valAcc))
        plot(ax, history.epochIter, history.valAcc, "ko--", "MarkerFaceColor", "k", "DisplayName", "検証 (エポックごと)");
    end
    if any(~isnan(history.monAcc))
        plot(ax, history.epochIter, history.monAcc, "rs-", "MarkerFaceColor", "r", "LineWidth", 1.2, "DisplayName", "テスト (表示のみ, エポックごと)");
    end
    ylim(ax, [0 100]); xlim(ax, [0 max(it)]);
    xlabel(ax, "反復"); ylabel(ax, "精度 (%)"); title(ax, titleText, "Interpreter", "none");
    legend(ax, "Location", "southeast"); grid(ax, "on"); box(ax, "on");
    exportgraphics(fig, pngFile, "Resolution", 150);
    close(fig);
end
