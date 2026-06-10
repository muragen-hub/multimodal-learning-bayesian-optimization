classdef RawData
    %RAWDATA excelから読み込んだデータ本体
    %   詳細説明をここに記述
    properties (SetAccess = immutable)
        date
        conditions
        measuredFreq % 測定周波数
        labels
        isNeedCorrect % 補正が必要かどうか
        correctConditions % どの条件で補正を施すか
        representative
        timeCell
        timeCell_second
        capacitanceCell
        labelCell %categorical配列にしたもの
        gasFlowRate % 流量計から拾ってきた気相流量
        liquidFlowRate % 流量計から拾ってきた液相流量
    end

    methods (Access = public)
        function RawData = RawData(date,measuredFreq,conditions,labels, isNeedCorrect, correctConditions, timeCell, timeCell_second, capacitanceCell,labelCell,nameAndVar)
            arguments
                date string
                measuredFreq {mustBePositive}
                conditions (1,:) string
                labels (1,:) string
                isNeedCorrect logical
                correctConditions (1,:) string
                timeCell (1,:) cell
                timeCell_second (1,:) cell
                capacitanceCell (1,:) cell
                labelCell (1,:) cell
                nameAndVar.gasFlowRate (1,:) cell = cell.empty();
                nameAndVar.liquidFlowRate (1,:) cell = cell.empty();
            end

            %RAWDATA このクラスのインスタンスを作成
            RawData.date = date;
            RawData.measuredFreq = measuredFreq;
            RawData.conditions = conditions;
            RawData.labels = labels;
            RawData.isNeedCorrect = isNeedCorrect;
            RawData.correctConditions = correctConditions;
            RawData.timeCell = timeCell;
            RawData.timeCell_second = timeCell_second;
            RawData.capacitanceCell = capacitanceCell;
            RawData.labelCell = labelCell;
            RawData.representative = createRepresentativeTable(RawData, conditions,timeCell,capacitanceCell);
            RawData.gasFlowRate = nameAndVar.gasFlowRate;
            RawData.liquidFlowRate = nameAndVar.liquidFlowRate;
        end

        function [] = viewAutoCorrelation(obj,maxLag,saveFolderName)
            %自己相関関数をコレログラムで可視化する.
            arguments
                obj RawData
                maxLag {mustBeInteger}
                saveFolderName string
            end
            saveDirName = append( PictureSavePath.path,saveFolderName,"/");
            if not(exist( saveDirName ,'dir'))
                mkdir( saveDirName )
            end
            for ii = 1:length(obj.conditions)
                figure;
                hold on
                [autocor,lags] = xcorr(obj.capacitanceCell{ii},maxLag,'coeff');
                [~,x_ofALLPeak] = findpeaks(autocor);
                xMeanOfShortPeriod = mean(diff(x_ofALLPeak));
                [y_ofLongPeak,x_ofLongPeak] = findpeaks(autocor,'MinPeakDistance',xMeanOfShortPeriod); % 見づらいため短周期の繰り返しは取り除く.
                plot(lags,autocor);
                plot(lags(x_ofLongPeak),y_ofLongPeak+0.02,'vk');
                xlabel('Lag');
                ylabel('Autocorrelation');
                xlim([0 Inf]);
                legend(obj.conditions(ii))
                hold off
                saveas(gcf, append(saveDirName,"Of_","Correlogram.fig"))
            end
        end

        function [] = viewCrossCorrelation(obj,maxLag,saveFolderName)
            %時系列データ間の相互相関を見る. 同じデータの時はヒストグラム, 異なるデータの時はscatterと共分散を出す. (Rがいくつかも求める. )
            arguments
                obj RawData
                maxLag {mustBeInteger}
                saveFolderName string
            end
            %特徴量の数 https://stackoverflow.com/questions/52313256/add-labels-for-x-and-y-using-the-plotmatrix-function-matlab
            featureLength = length(obj.capacitanceCell{1});
            for ii = 1:length(obj.conditions)
                figure;
                hold on
                [autocor,lags] = xcorr(obj.capacitanceCell{ii},maxLag,'coeff');
                [~,x_ofALLPeak] = findpeaks(autocor);
                xMeanOfShortPeriod = mean(diff(x_ofALLPeak));
                [y_ofLongPeak,x_ofLongPeak] = findpeaks(autocor,'MinPeakDistance',xMeanOfShortPeriod); % 見づらいため短周期の繰り返しは取り除く.
                plot(lags,autocor);
                plot(lags(x_ofLongPeak),y_ofLongPeak+0.02,'vk');
                xlabel('Lag');
                ylabel('Autocorrelation');
                xlim([0 Inf]);
                legend(obj.conditions(ii))
                hold off
                saveas(gcf, append(saveDirName,"Of_","Correlogram.fig"))
            end
        end

        function [] = viewWaveAfterFilter(obj,saveFolderName,ylim)
            arguments
                obj RawData
                saveFolderName string
                ylim (1,:)
            end
            saveDirName = append( PictureSavePath.path,saveFolderName,"/");
            if not(exist( saveDirName ,'dir'))
                mkdir( saveDirName )
            end
            obj.allWave(saveDirName, ylim)
        end

        function [] = view(obj,saveFolderName,measuredFreq, ylim)
            arguments
                obj RawData
                saveFolderName string
                measuredFreq {mustBePositive}
                ylim (1,:)
            end
            saveDirName = append( PictureSavePath.path,saveFolderName,"/");
            if not(exist( saveDirName ,'dir'))
                mkdir( saveDirName )
            end
            obj.allWave(saveDirName, ylim)
            obj.measuredFreqIsConstCheck(saveDirName,measuredFreq)
        end

        function [] = viewWaveOfFeature(obj,conditionNum,saveFolderName,ylimArray,varAndName)
            arguments
                obj RawData
                conditionNum  {mustBeNumeric,mustBePositive}
                saveFolderName string
                ylimArray (1,:)
                varAndName.featureNum {mustBeNumeric,mustBePositive}= 1;
            end
            saveDirName = append( PictureSavePath.path,saveFolderName,"/");
            if not(exist( saveDirName ,'dir'))
                mkdir( saveDirName )
            end
            figure;
            hold on;
            plot(obj.capacitanceCell{conditionNum}(1:end,varAndName.featureNum),'.','MarkerSize',4);
            xlabel("Data number");
            ylabel("Corrected electrostatic capacity");
            %ylim(ylimArray)
            xlim([0 inf])
            hold off;
            saveas(gcf, append(saveDirName,"data",".fig"));
            saveas(gcf, append(saveDirName,"data",".png"));
        end

        function [] = viewFFT(obj, folderName,givenTitle,varAndName)
            arguments
                obj RawData
                folderName string
                givenTitle string
                varAndName.featureName (1,:) string = string.empty();
                varAndName.minimumLength (1,:) {mustBeNumeric} = 1000;
            end
            featureLength = size(obj.capacitanceCell{1},2);
            for iCondition=1:length(obj.conditions)
                conditionName = obj.conditions(iCondition);
                dirName = append(PictureSavePath.path,folderName,conditionName,"/");
                if not(exist( dirName ,'dir'))
                    mkdir( dirName )
                end
                for iFeature = 1:featureLength
                    figure
                    hold on
                    %FFTのチュートリルからほぼそのまま取ってきてます.
                    t = obj.timeCell_second{iCondition}(1:varAndName.minimumLength); %テーブルの1行目がsecond単位の秒数
                    t = seconds(t) *1000; %tはそのままではdurationのため数値へ変換, fftはミリ秒らしいので変換
                    Y = fft(obj.capacitanceCell{iCondition}(1:varAndName.minimumLength,iFeature));
                    P2 = abs(Y/length(t)); %t(end)で総計測時間に相当
                    P1 = P2(1:fix(length(t)/2)+1); %ナイキスト周波数以下でないといけないので片側のみ取ってくる. 切り捨てなのでt(end)/2として少数になっても大丈夫
                    P1(2:end-1) = 2*P1(2:end-1); % 多分ここの2倍はFFTの結果が振幅の1/2で出てくるようになっているため, その修正.
                    % ↑: P1(1) と P1(end) に 2を乗算する必要はありません。
                    % これらの振幅はそれぞれゼロ周波数とナイキスト周波数に対応し、負の周波数では複素共役のペアをもたないからです。
                    % らしい
                    f = obj.measuredFreq/fix(length(t))*(0:(fix(length(t)/2)));

                    plot(f,P1,"-k");
                    %xline(obj.measuredFreq/2); % ナイキスト周波数

                    xlabelobj = xlabel('Frequency Hz');
                    ylabelobj = ylabel(['Absolute value of its frequency component']);

                    FSize = 14;
                    ylabelobj.FontSize = FSize;
                    xlabelobj.FontSize = FSize;
                    fontName = 'Times New Roman';
                    ylabelobj.FontName = fontName;
                    xlabelobj.FontName = fontName;

                    averageFreq = sum(P1.*transpose(f))/sum(P1);
                    averageFreqExcludeConstant = sum(P1(2:end).*transpose(f(2:end)))/sum(P1(2:end));

                    if ~isempty(varAndName.featureName)
                        subtitle(append("Condition: ", obj.conditions(iCondition),newline,"FeatureNumOf: ",varAndName.featureName(iFeature),newline,"Average frequency: ",string(averageFreq)," Hz",newline,"Average Frequency excluding constant: ",string(averageFreqExcludeConstant),"Hz"));
                        saveas(gcf, append( dirName ,"CondOf",obj.conditions(iCondition),"FeatureNumOf",varAndName.featureName(iFeature),"_FFT.fig"))
                        saveas(gcf, append( dirName ,"CondOf",obj.conditions(iCondition),"FeatureNumOf",varAndName.featureName(iFeature),"_FFT.png"))
                    else
                        title(append(givenTitle,"in", obj.conditions(iCondition),"ofFeature",string(iFeature)),'Units', 'normalized', 'Position', [0.5, -0.135, 0])
                        saveas(gcf, append( dirName ,"CondOf",obj.conditions(iCondition),"FeatureNumOf",string(iFeature),"_FFT.fig"))
                        saveas(gcf, append( dirName ,"CondOf",obj.conditions(iCondition),"FeatureNumOf",string(iFeature),"_FFT.png"))
                    end
                    hold off
                    %スカログラム
                    % [MEMO] マザーウェーブレットはとりあえずmorseでいいかなと，本当はsym4などの直交ウェーブレットを使用したいが．信号分解で使用しているため。
                    figure;
                    cwt(obj.capacitanceCell{iCondition}(1:varAndName.minimumLength,iFeature),"morse",obj.measuredFreq);
                    if ~isempty(varAndName.featureName)
                        subtitle(append("Condition: ", obj.conditions(iCondition),newline,"FeatureNumOf ",varAndName.featureName(iFeature)));
                        saveas(gcf, append( dirName ,"CondOf",obj.conditions(iCondition),"FeatureNumOf",varAndName.featureName(iFeature),"_Scalogram.fig"))
                        saveas(gcf, append( dirName ,"CondOf",obj.conditions(iCondition),"FeatureNumOf",varAndName.featureName(iFeature),"_Scalogram.png"))
                    else
                        saveas(gcf, append( dirName ,"CondOf",obj.conditions(iCondition),"FeatureNumOf",string(iFeature),"_Scalogram.fig"))
                        saveas(gcf, append( dirName ,"CondOf",obj.conditions(iCondition),"FeatureNumOf",string(iFeature),"_Scalogram.png"))
                    end
                end
                close all hidden;
            end
        end

        function [] = viewPlotOnly(obj,saveFolderName, ylimArray,varAndName)
            arguments
                obj RawData
                saveFolderName string
                ylimArray (1,:)
                varAndName.featureNum {mustBeNumeric, mustBePositive} = 1
            end
            saveDirName = append( PictureSavePath.path,saveFolderName,"/");
            if not(exist( saveDirName ,'dir'))
                mkdir( saveDirName )
            end
            for i = 1:length(obj.conditions)
                figure;
                hold on;
                plot(obj.timeCell_second{i},obj.capacitanceCell{i}(:,varAndName.featureNum),'.','MarkerSize',4);
                hold off;
                ylim(ylimArray);
                ylabel("Electrostatic capacity F")
                xlabel("time s")
                saveas(gcf, append( saveDirName,obj.conditions(i),"AllWave.fig"))
            end
        end
    end

    methods (Access = private)
        function [] = allWave(obj,saveDirName,ylimArray)
            for i = 1:length(obj.conditions)
                figure;
                hold on;
                plot(obj.timeCell_second{i},obj.capacitanceCell{i})%,'.','MarkerSize',4);
                yline(obj.representative.min{i},'b-',{append("min",string(obj.representative.min(i)))});
                yline(obj.representative.max{i},'r-',{append("max",string(obj.representative.max(i)))});
                yline(obj.representative.average{i},'k-',{append("average",string(obj.representative.average(i)))});
                hold off;
                ylim(ylimArray);
                %xlim([0 60]); %[TODO] xlimも指定できる用にした方が良い.
                ylabel("静電容量 F")
                xlabel("時間 s")
                legend(["データ本体" "最小値" "最大値" "平均値"]);
                title(obj.conditions(i),'Units', 'normalized', 'Position', [0.5, -0.135, 0])
                saveas(gcf, append( saveDirName,obj.conditions(i),"AllWave.fig"))
            end
        end

        function [] = measuredFreqIsConstCheck(obj,saveDirName,measuredFreq)
            for i = 1:length(obj.conditions)
                figure
                plot(diff(obj.timeCell_second{i}),'k-')
                ylabel("前の測定時間との時間の差分 s")
                xlabel("測定番号")
                ylim([seconds(0) seconds(0.05)]);
                yline(1/measuredFreq,'r-');
                legend(["測定間隔", "適正間隔"])
                title(obj.conditions(i),'Units', 'normalized', 'Position', [0.5, -0.135, 0])
                saveas(gcf, append( saveDirName, obj.conditions(i),"TimeDelta(For FreqCheck).fig"))
            end
        end
    end

    methods (Access = private)
        function representativeTable = createRepresentativeTable(obj,conditions,timeCell, capacitanceCell)
            arguments
                obj RawData
                conditions (1,:) string
                timeCell (1,:) cell
                capacitanceCell (1,:) cell
            end
            %代表値の取り出し
            timeValue = transpose(cellfun(@numel,timeCell,UniformOutput=false));
            capaValue = transpose(cellfun(@numel,capacitanceCell,UniformOutput=false));
            average = transpose(cellfun(@mean, capacitanceCell,UniformOutput=false));
            min = transpose(cellfun(@min, capacitanceCell,UniformOutput=false));
            max = transpose(cellfun(@max, capacitanceCell,UniformOutput=false));
            %見やすくするため、テーブル配列を作成する
            condition = transpose(conditions);
            representativeTable = table(condition, timeValue, capaValue,  max, min, average);
            %テーブルに値は格納したので解放する
            clear timeValue capaValue average min max
        end
    end
end

