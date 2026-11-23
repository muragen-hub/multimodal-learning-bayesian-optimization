function X = toArray(W)
%TOARRAY {N x 1} の [C x W] 窓 → [C x W x N] の single 配列.
    X = single(cat(3, W{:}));
end
