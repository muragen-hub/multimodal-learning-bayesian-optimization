function [W, starts] = makeWindows(vf, dp, width, stride)
%MAKEWINDOWS 2ch の窓 {N x 1} を作る. 各要素は [2 x width] (1行目 = ボイド率, 2行目 = 差圧).
%   starts は各窓の開始位置 (点, 1始まり).
    n = numWindows(numel(vf), width, stride);
    starts = (0:n - 1)' * stride + 1;
    W = cell(n, 1);
    for j = 1:n
        s = starts(j);
        W{j} = [vf(s:s + width - 1)'; dp(s:s + width - 1)'];
    end
end
