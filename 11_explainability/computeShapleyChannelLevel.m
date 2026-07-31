function explainer = computeShapleyChannelLevel(allVF, allPr, forwardFcn, targetClassIdx, bgIdx, queryIdx, nameAndVar)
%COMPUTESHAPLEYCHANNELLEVEL VF波形・Pr波形をそれぞれ1プレイヤーとして扱うチャンネル単位Shapley値.
%   deepLearning_wave_multimodalClassification.mlx の学習済みモデル(2ch入力の単一biLSTM)
%   を対象とする. 特徴量(チャンネル)は2つのみのため, shapleyは厳密な全列挙(2^2=4通り)で
%   計算される(Kernel SHAPの近似は不要).
%
%   allVF, allPr: 全候補サンプルのデータプール(train/testを跨いでも良い).
%                 queryIdx, bgIdx はこのプールへの添字.
%   forwardFcn: @(vfBatch, prBatch) -> scoresMatrix(行=サンプル, 列=クラス)
%               実データでの結線例:
%               forwardFcn = @(vfBatch, prBatch) ...
%                   extractdata(predict(net, wavesToCTB(vfBatch, prBatch), Outputs=["softmax"]))';
%   targetClassIdx: 寄与度を説明する対象クラスの列番号
%   bgIdx: 背景(参照)サンプルの添字ベクトル
%   queryIdx: 説明したいクエリサンプルの添字(スカラー)
%
%   explainer.Shapley.Value(1) = VFチャンネルの寄与度, (2) = Prチャンネルの寄与度
%   (バックグラウンドテーブルの列順 VFIdx, PrIdx に対応)

    arguments
        allVF (:,1) cell
        allPr (:,1) cell
        forwardFcn function_handle
        targetClassIdx {mustBePositive, mustBeInteger}
        bgIdx (1,:) {mustBePositive, mustBeInteger}
        queryIdx (1,1) {mustBePositive, mustBeInteger}
        nameAndVar.UseParallel (1,1) logical = false
    end

    bgIdxCol = bgIdx(:);
    backgroundTable = table(bgIdxCol, bgIdxCol, 'VariableNames', {'VFIdx','PrIdx'});
    queryTable = table(queryIdx, queryIdx, 'VariableNames', {'VFIdx','PrIdx'});

    blackbox = @(T) channelBlackboxScore(T, allVF, allPr, forwardFcn, targetClassIdx);

    explainer = shapley(blackbox, backgroundTable, ...
        'QueryPoints', queryTable, ...
        'NumObservationsToSample', 'all', ...
        'UseParallel', nameAndVar.UseParallel);
end
