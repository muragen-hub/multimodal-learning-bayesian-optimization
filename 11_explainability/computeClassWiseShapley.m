function meanAbsShap = computeClassWiseShapley(shapleyFcn, numFeatures, allLabel, classes, bgIdx, nameAndVar)
%COMPUTECLASSWISESHAPLEY クラス(流動様式)ごとに複数クエリサンプルのShapley値を平均する.
%   VF_mean/Pr_stdなどの支配的特徴量がクラスによって異なるという仮説を検証するには,
%   全体で1つに集約したShapley値ではなくクラスごとの値が必要 (設計メモの出力要件).
%
%   shapleyFcn: @(targetClassIdx, queryIdx) -> explainer
%               computeShapleyChannelLevel / computeShapleyPhysicalStats を
%               他の引数を固定してbindした関数ハンドルを渡す.
%   numFeatures: explainer.Shapley.Value の要素数(チャンネル単位なら2, 統計量ベースなら5)
%   allLabel: (:,1) categorical, データプール全体のラベル(shapleyFcnが参照する
%             queryIdxに対応する添字を持つ)
%   classes: (:,1) categorical, targetClassIdx=1,2,...の順序に対応するクラス一覧
%            (例: categories(categorical(train.labelStrings)))
%   bgIdx: 背景サンプルの添字(クエリサンプル選定時にこのプールを除外する)
%   nameAndVar.MaxQueriesPerClass: クラスあたり平均するクエリサンプル数の上限(デフォルト20)
%
%   meanAbsShap: numClasses x numFeatures 行列. 行=クラス(classesの順), 列=特徴量
%                (shapleyFcnの背景テーブル列順と対応).
    arguments
        shapleyFcn function_handle
        numFeatures {mustBePositive, mustBeInteger}
        allLabel (:,1) categorical
        classes (:,1) categorical
        bgIdx (1,:) {mustBePositive, mustBeInteger}
        nameAndVar.MaxQueriesPerClass (1,1) {mustBePositive, mustBeInteger} = 20
    end

    numClasses = numel(classes);
    meanAbsShap = zeros(numClasses, numFeatures);

    for c = 1:numClasses
        classQueryIdx = find(allLabel == classes(c))';
        classQueryIdx = setdiff(classQueryIdx, bgIdx, 'stable');
        if numel(classQueryIdx) > nameAndVar.MaxQueriesPerClass
            classQueryIdx = classQueryIdx(randperm(numel(classQueryIdx), nameAndVar.MaxQueriesPerClass));
        end

        valuesMat = zeros(numel(classQueryIdx), numFeatures);
        for i = 1:numel(classQueryIdx)
            explainer = shapleyFcn(c, classQueryIdx(i));
            valuesMat(i, :) = abs(explainer.Shapley.Value)';
        end
        meanAbsShap(c, :) = mean(valuesMat, 1);
    end
end
