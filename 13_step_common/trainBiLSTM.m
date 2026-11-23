function bestNet = trainBiLSTM(net, Xtr, Ytr, Xval, Yval, classes, learnRate, maxEpoch, batchSize, patience)
%TRAINBILSTM Adam + 勾配クリップ (L2ノルム 1) で学習する. 検証の損失が最小の時点のネットワークを返す.
%   Xtr, Xval: [C x W x N] の single 配列, Ytr, Yval: 流動様式の string ベクトル, classes: クラス名.
%   deepLearning_wave_2026_conditionCV.m の学習ループと同じ内容 (Step 1 のスクリプトは実行中なので触っていない).
    Ttr = single(Ytr(:)' == classes(:));        % one-hot [クラス数 x N]
    Tval = single(Yval(:)' == classes(:));
    n = size(Xtr, 3);
    avgG = []; avgSqG = []; iter = 0;
    bestLoss = Inf; bestNet = net; noImprove = 0;
    for epoch = 1:maxEpoch
        order = randperm(n);
        for s = 1:batchSize:(n - batchSize + 1)
            idx = order(s:s + batchSize - 1);
            iter = iter + 1;
            dlX = dlarray(Xtr(:, :, idx), "CTB");
            T = Ttr(:, idx);
            if canUseGPU, dlX = gpuArray(dlX); T = gpuArray(T); end
            [~, grad] = dlfeval(@modelLoss, net, dlX, T);
            grad = dlupdate(@clipL2, grad);
            [net, avgG, avgSqG] = adamupdate(net, grad, avgG, avgSqG, iter, learnRate);
        end
        [valLoss, valAcc] = evaluateSet(net, Xval, Tval);
        fprintf("    エポック %2d: 検証の損失 %.4f, 検証の正解率 %.1f%%\n", epoch, valLoss, 100 * valAcc);
        if valLoss < bestLoss
            bestLoss = valLoss; bestNet = net; noImprove = 0;
        else
            noImprove = noImprove + 1;
            if noImprove >= patience, break; end
        end
    end
end

function [loss, grad] = modelLoss(net, dlX, T)
    Y = stripdims(forward(net, dlX));          % 書式つきの出力から書式を外す (DataFormat を指定するため)
    loss = crossentropy(Y, T, "DataFormat", "CB");
    grad = dlgradient(loss, net.Learnables);
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
