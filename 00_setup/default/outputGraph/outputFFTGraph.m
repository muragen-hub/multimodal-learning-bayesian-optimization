function [] = outputFFTGraph(measuredFreq, conditions, tabledData,folderName,givenTitle)
%FFTGRAPHOUTPUT フィルター後の周波数振幅成分の表示
% 0Hz周辺の値が大きすぎるので, 0.1Hzから表示する.
% folderName: 最後の/を忘れないで.(面倒なので引数の検証とか省いてます.)
dirName = append("pictures/",folderName);
if not(exist( dirName ,'dir'))
    mkdir( dirName )
end


for i=1:length(conditions)
    figure
    %FFTのチュートリルからほぼそのまま取ってきてます.
    t = tabledData{i}.Time; %テーブルの1行目がsecond単位の秒数
    t = seconds(t) *1000; %tはそのままではdurationのため数値へ変換, fftはミリ秒らしいので変換
    Y = fft(tabledData{i}.capa);
    P2 = abs(Y/length(t)); %t(end)で総計測時間に相当
    P1 = P2(1:fix(length(t)/2)+1); %ナイキスト周波数以下でないといけないので片側のみ取ってくる. 切り捨てなのでt(end)/2として少数になっても大丈夫
    P1(2:end-1) = 2*P1(2:end-1); % 多分ここの2倍はFFTの結果が振幅の1/2で出てくるようになっているため, その修正.
    f = measuredFreq*(0:(length(t)/2))/length(t);
    
    plot(f,P1) 
    ylim([0 (10.^(-14))]);
    xlim([0.1 measuredFreq/2]); %0Hz周辺の値が大きすぎるので, 0.1Hzからナイキスト周波数までを表示する.
    xlabel('周波数f (Hz)');
    ylabel(['複素振幅の絶対値　F']);
    title(append(givenTitle, conditions(i)),'Units', 'normalized', 'Position', [0.5, -0.135, 0])
    saveas(gcf, append( dirName , conditions(i),"FFT.fig"))
end
end

