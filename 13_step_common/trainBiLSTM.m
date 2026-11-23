function [bestNet, history] = trainBiLSTM(net, Xtr, Ytr, Xval, Yval, classes, learnRate, maxEpoch, batchSize, patience, Xmon, Ymon)
%TRAINBILSTM Adam + 勾配クリップ (L2ノルム 1) で学習する.
%   Xtr, Xval: [C x W x N] の single 配列, Ytr, Yval: 流動様式の string ベクトル, classes: クラス名.
%   Xval が空のとき: 検証を使わず, 固定エポック数で学習して最後のネットワークを返す.
%   Xval があるとき: 検証損失が最小の時点のネットワークを返す (patience エポック続けて下がらなければ終了).
%   Xmon, Ymon (省略可): 「表示だけ」に使う監視用データ (例: テストデータ). 学習の判断には一切使わない.
%   history: 学習の進行の記録. trainAcc / trainLoss は反復ごと, epochIter / valAcc / valLoss / monAcc はエポックごと.
    if nargin < 11, Xmon = []; Ymon = strings(0, 1); end
    Ttr = single(Ytr(:)' == classes(:));        % one-hot [クラス数 x N]
    Tval = single(Yval(:)' == classes(:));
    Tmon = single(Ymon(:)' == classes(:));
    n = size(Xtr, 3);
    avgG = []; avgSqG = []; iter = 0;
    bestLoss = Inf; bestNet = net; noImprove = 0;
    history = struct("trainAcc", [], "trainLoss", [], "epochIter", [], "valAcc", [], "valLoss", [], "monAcc", []);
    for epoch = 1:maxEpoch
        order = randperm(n);
        for s = 1:batchSize:(n - batchSize + 1)
            idx = order(s:s + batchSize - 1);
            iter = iter + 1;
            dlX = dlarray(Xtr(:, :, idx), "CTB");
            T = Ttr(:, idx);
            if canUseGPU, dlX = gpuArray(dlX); T = gpuArray(T); end
            [loss, grad, acc] = dlfeval(@modelLoss, net, dlX, T);
            grad = dlupdate(@clipL2, grad);
            [net, avgG, avgSqG] = adamupdate(net, grad, avgG, avgSqG, iter, learnRate);
            history.trainAcc(end + 1) = double(gather(acc));
            history.trainLoss(end + 1) = double(gather(extractdata(loss)));
        end
        history.epochIter(end + 1) = iter;
        % 表示用の監視 (テストデータなど). 学習の判断には使わない
        monAcc = NaN;
        if ~isempty(Xmon)
            [~, monAcc] = evaluateSet(net, Xmon, Tmon); monAcc = 100 * monAcc;
        end
        history.monAcc(end + 1) = monAcc;
        nIterEpoch = floor(n / batchSize);
        trainAccEpoch = mean(history.trainAcc(end - nIterEpoch + 1:end));
        if isempty(Xval)   % 検証を使わない: 固定エポック数で学習し, 最後のネットワークを使う
            history.valAcc(end + 1) = NaN; history.valLoss(end + 1) = NaN;
            fprintf("    エポック %2d 終了 (学習の正解率 %.1f%%, 監視 %.1f%%)\n", epoch, trainAccEpoch, monAcc);
            bestNet = net;
            continue;
        end
        [valLoss, valAcc] = evaluateSet(net, Xval, Tval);
        history.valAcc(end + 1) = 100 * valAcc; history.valLoss(end + 1) = valLoss;
        fprintf("    エポック %2d: 学習の正解率 %.1f%%, 検証の損失 %.4f, 検証の正解率 %.1f%% (監視 %.1f%%)\n", epoch, trainAccEpoch, valLoss, 100 * valAcc, monAcc);
        if valLoss < bestLoss
            bestLoss = valLoss; bestNet = net; noImprove = 0;
        else
            noImprove = noImprove + 1;
            if noImprove >= patience, break; end
        end
    end
end

function [loss, grad, acc] = modelLoss(net, dlX, T)
    Y = stripdims(forward(net, dlX));          % 書式つきの出力から書式を外す (DataFormat を指定するため)
    loss = crossentropy(Y, T, "DataFormat", "CB");
    grad = dlgradient(loss, net.Learnables);
    [~, p] = max(gather(extractdata(Y)), [], 1);   % ミニバッチの正解率 (記録用)
    [~, t] = max(gather(T), [], 1);
    acc = 100 * mean(p == t);
end

function g = clipL2(g)
    nrm = sqrt(sum(g.^2, "all"));
    if nrm > 1, g = g / nrm; end
end

function [loss, acc] = evaluateSet(net, X, T)
    n = size(X, 3); batch = 512; lossSum = 0; correct = 0;
    for s = 1:batch:n
        idx = s:min(s + batch - 1, n);
        dlX = dlarray(X(:, :, idx), "CTB");
        if canUseGPU, dlX = gpuArray(dlX); end
        Y = gather(extractdata(predict(net, dlX)));
        lossSum = lossSum + double(crossentropy(dlarray(Y, "CB"), dlarray(T(:, idx), "CB"))) * numel(idx);
        [~, p] = max(Y, [], 1); [~, t] = max(T(:, idx), [], 1);
        correct = correct + sum(p == t);
    end
    loss = lossSum / n; acc = correct / n;
end
