conditions= ["L1.5G1" "L1.5G25" "L1.5G50" "L3G1" "L3G25" "L3G50" "L4.5G1" "L4.5G25" "L4.5G50" "L6G1" "L6G25" "L6G50"];
[cellOfTimeTables,representative]= createConstFreqTimeTable("resources/data/20211209",conditions,80);
cellOfFilterdTimeTable = lowPassFilterWrapper(cellOfTimeTables,40);
[data, label]  = createFormedDataFromTimeTable(conditions, cellOfFilterdTimeTable,1,0,300);
outputInitailWidthWave(conditions_12, data,"2021Result/1217Wave/","noFIlter")
outputFFTGraph(80, conditions,cellOfFilterdTimeTable,"2021Result/1209Wave/FFT/40Hzthreshold/","40HzFilter(noFilter)");

%{
    学習部もラップする必要を感じた時用のガジェット的な
    % 学習用(モデル内の重みの更新に使われる)とテスト用(重みの更新をしても精度がもう上がりきらないかどうかを決めるために使われる)のデータの生成
    [trainStr,trainConditionsIndex ,~] = intersect(sortedCondition, trainConditions);
    [testStr, testConditionsIndex, ~] = intersect(sortedCondition, testConditions);
    disp(['trainData: ', trainStr]);
    disp(['testData', testStr]);
%}
disp("ok")

%% 試行錯誤用
sources = "resources/data/20201030/L6G1/ALLDATA.csv";
tmp = readmatrix(sources);

time = (tmp(:,1) - tmp(1,1))/10^5;
capa = tmp(:,2);

clear tmp;
timeTable = timetable(seconds(time), capa); %Timetableはdurationでないといけない.

figure
plot(time, capa)
title('before resample');

nonOutliersTimeTable = rmoutliers(timeTable, 'ThresholdFactor',10);

desiredFs = 50;
wellFormedTimeTable = retime(nonOutliersTimeTable,'regular','linear','SampleRate',desiredFs); %おかしなデータは線形内挿.

clear nonOutliersTimeTable;

figure
plot(wellFormedTimeTable.Time, wellFormedTimeTable.capa);
title('after resample')

pspectrum(wellFormedTimeTable);

Fs = 1000; %fft用の周波数. 実際のサンプリング周波数ではない.
T = 1/Fs;      % Sampling period       
L = numel(wellFormedTimeTable);             % Length of signal
t = (0:L-1)*T;        % Time vector

Y = fft(wellFormedTimeTable.capa);

P2 = abs(Y/L);
P1 = P2(1:fix(L/2)+1);
P1(2:end-1) = 2*P1(2:end-1);

f = Fs*(0:(L/2))/L;

figure;
plot(f,P1) 
title('Single-Sided Amplitude Spectrum of X(t)')
xlim([1 25]) %殆どがおそらく定数. それはそう.
xlabel('f (Hz)')
ylabel('|P1(f)|')

lowpassed = lowpass(wellFormedTimeTable , 10);

Y = fft(lowpassed.capa);

P2 = abs(Y/L);
P1 = P2(1:fix(L/2)+1);
P1(2:end-1) = 2*P1(2:end-1);

f = Fs*(0:(L/2))/L;

figure;
plot(f,P1) 
title('Lowpassed Single-Sided Amplitude Spectrum of X(t)')
xlim([1 25]) %殆どがおそらく定数. それはそう.
xlabel('f (Hz)')
ylabel('|P1(f)|')

pspectrum(lowpassed )

%[TODO] FFTはその周波数によって結果が変わってしまうようなので少し調査が必要.




