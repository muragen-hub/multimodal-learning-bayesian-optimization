function P = predictProbabilities(net, W, classes)
%PREDICTPROBABILITIES 窓ごとの各クラスの確率 [N x クラス数].
    X = toArray(W);
    n = size(X, 3);
    P = zeros(n, numel(classes));
    batch = 512;
    for s = 1:batch:n
        idx = s:min(s + batch - 1, n);
        dlX = dlarray(X(:, :, idx), "CTB");
        if canUseGPU, dlX = gpuArray(dlX); end
        Y = predict(net, dlX);
        P(idx, :) = gather(extractdata(Y))';
    end
end
