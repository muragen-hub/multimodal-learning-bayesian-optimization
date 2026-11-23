function n = numWindows(len, width, stride)
%NUMWINDOWS 長さ len の時系列から, 幅 width の窓を stride ずつずらして取ったときの窓の数.
    n = max(floor((len - width) / stride) + 1, 0);
end
