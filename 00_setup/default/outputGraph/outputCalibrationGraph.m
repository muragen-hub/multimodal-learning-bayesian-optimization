function [] = outputCalibrationGraph(src, conditions,folderName)
%CALIBRATIONGRAPHOUTPUT 実験前にCメータの値が落ち着いているのかどうかを測定したが, それに関して各測定条件でL0,L100で基準がずれていないかを確認するためのもの.
%src: G30_after_L1.5フォルダなどが置かれているフォルダの名前
%conditions: [WARNING] L1.5, L3などLの方の条件のみを指定する. これは気相の最後はL1.5などで指定されていることに加え, 液相100の方の条件もL1.5G0などのようにLさえ分かっていれば良くなっているため.
%folderName: 最後の/を忘れないで.(面倒なので引数の検証とか省いてます.)
dirName = append("pictures/",folderName);
if not(exist( dirName ,'dir'))
    mkdir( dirName )
end

conditionsLength = length(conditions);

%まずはL0の方, つまりG30_after_L~の方.
sources = append(src,"/" ,"G30_before_", conditions,"/ALLDATA.csv");
rawdata_time = cell(1, conditionsLength);
rawdata_capa = cell(1, conditionsLength);
%データの形式として, ALLDATAの１列目が時間で２列目が静電容量
for i = 1:conditionsLength
    tmp= readmatrix(sources(i));
    rawdata_time{i} = tmp(1: end,1);
    rawdata_capa{i} = tmp(1: end,2);
end

figure
hold on
for i=1:length(conditions)
    plot(rawdata_capa{i});
end
hold off

ylim([2*(10.^(-13)) 4.5*(10.^(-13))]);
ylabel("静電容量 F")
xlabel("測定番号")
legends = append('G30\_before\_', conditions);
legend(legends);
title("L0CalibrationResult",'Units', 'normalized', 'Position', [0.5, -0.135, 0])
saveas(gcf, append( dirName , "L0Calibration.fig"))

%次にL100の方, つまりL~G0の方.
sources = append(src,"/", conditions,"G0","/ALLDATA.csv");
rawdata_time = cell(1, conditionsLength);
rawdata_capa = cell(1, conditionsLength);
%データの形式として, ALLDATAの１列目が時間で２列目が静電容量
for i = 1:conditionsLength
    tmp= readmatrix(sources(i));
    rawdata_time{i} = tmp(1: end,1);
    rawdata_capa{i} = tmp(1: end,2);
end

figure
hold on
for i=1:length(conditions)
    plot(rawdata_capa{i});
end
hold off
ylim([2*(10.^(-13)) 4.5*(10.^(-13))]);
ylabel("静電容量 F")
xlabel("測定番号")
legends = append(conditions, "G0");
legend(legends);
title("L100CalibrationResult",'Units', 'normalized', 'Position', [0.5, -0.135, 0])
saveas(gcf, append( dirName , "L100Calibration.fig"))
end
