classdef RawDataTwo
    %RAWDATA excelから読み込んだデータ本体
    %   詳細説明をここに記述
    properties (SetAccess = immutable)
        date
        conditions
        measuredFreq % 測定周波数
        labels
        isNeedCorrect % 補正が必要かどうか
        correctConditions % どの条件で補正を施すか
        correctFlowRegimes % 流動様式の補正情報
        representative
        timeCell
        timeCell_second
        capacitanceCell
        flowRegimeCell
        featureCell
        machineLearningCell
        labelCell % categorical配列にしたもの
        gasFlowRate % 流量計から拾ってきた気相流量
        liquidFlowRate % 流量計から拾ってきた液相流量
        differentialPressure % 差圧データ
    end

    methods (Access = public)
        function RawDataTwo = RawDataTwo( ...
            date, measuredFreq, conditions, labels, ...
            isNeedCorrect, correctConditions, ...
            timeCell, timeCell_second, capacitanceCell, flowRegimeCell, ...
            featureCell, machineLearningCell, labelCell, ...
            correctFlowRegimes, nameAndVar)
        
        arguments
            % ===== 必須引数 =====
            date string
            measuredFreq {mustBePositive}
            conditions (1,:) string
            labels (1,:) string
        
            isNeedCorrect logical
            correctConditions (1,:) string
        
            timeCell (1,:) cell
            timeCell_second (1,:) cell
            capacitanceCell (1,:) cell
            flowRegimeCell (1,:) cell
            featureCell (:,:) cell
            machineLearningCell (:,:) cell
            labelCell (1,:) cell
        
            % ===== オプション引数 =====
            correctFlowRegimes (1,:) cell = cell.empty()
        
            % ===== Name-Value パラメータ =====
            nameAndVar.gasFlowRate (1,:) cell = cell.empty()
            nameAndVar.liquidFlowRate (1,:) cell = cell.empty()
            nameAndVar.differentialPressure (1,:) cell = cell.empty()
        end


            RawDataTwo.date = date;
            RawDataTwo.measuredFreq = measuredFreq;
            RawDataTwo.conditions = conditions;
            RawDataTwo.labels = labels;
            RawDataTwo.isNeedCorrect = isNeedCorrect;
            RawDataTwo.correctConditions = correctConditions;
            RawDataTwo.correctFlowRegimes = correctFlowRegimes;
            RawDataTwo.timeCell = timeCell;
            RawDataTwo.timeCell_second = timeCell_second;
            RawDataTwo.capacitanceCell = capacitanceCell;
            RawDataTwo.flowRegimeCell = flowRegimeCell;
            RawDataTwo.featureCell = featureCell;
            RawDataTwo.machineLearningCell = machineLearningCell;
            RawDataTwo.labelCell = labelCell;
            RawDataTwo.representative = createRepresentativeTable(RawDataTwo,conditions,timeCell,capacitanceCell);
            RawDataTwo.gasFlowRate = nameAndVar.gasFlowRate;
            RawDataTwo.liquidFlowRate = nameAndVar.liquidFlowRate;
            RawDataTwo.differentialPressure = nameAndVar.differentialPressure;
        end

        %% ===== 可視化関数 =====
        function [] = viewAutoCorrelation(obj,maxLag,saveFolderName)
            %自己相関関数をコレログラムで可視化する. NaNを含むデータはrmmissingで除外して実行.
            arguments
                obj RawDataTwo
                maxLag {mustBeInteger}
                saveFolderName string
            end
            saveDirName = append(PictureSavePath.path,saveFolderName,"/");
            if ~exist(saveDirName,'dir'), mkdir(saveDirName); end
            for ii = 1:length(obj.conditions)
                figure; hold on
                % NaNを含む要素を除去してxcorrを実行
                data = rmmissing(obj.capacitanceCell{ii});
                [autocor,lags] = xcorr(data,maxLag,'coeff');
                
                [~,x_ofALLPeak] = findpeaks(autocor);
                % 短周期の繰り返しを取り除くためのMinPeakDistanceを計算
                if isempty(x_ofALLPeak)
                    xMeanOfShortPeriod = 1; 
                else
                    xMeanOfShortPeriod = mean(diff(x_ofALLPeak));
                end
                
                [y_ofLongPeak,x_ofLongPeak] = findpeaks(autocor,'MinPeakDistance',xMeanOfShortPeriod);
                plot(lags,autocor);
                plot(lags(x_ofLongPeak),y_ofLongPeak+0.02,'vk');
                xlabel('Lag'); ylabel('Autocorrelation'); xlim([0 Inf]);
                legend(obj.conditions(ii))
                hold off
                saveas(gcf, append(saveDirName,obj.conditions(ii),"_Correlogram.fig"))
            end
        end

        % function [] = viewCrossCorrelation(obj,maxLag,saveFolderName)
        %     % viewAutoCorrelationとロジックが重複するため削除 (相互相関機能が必要であれば再実装を推奨)
        % end

        function [] = viewWaveAfterFilter(obj,saveFolderName,ylim)
            arguments
                obj RawDataTwo
                saveFolderName string
                ylim (1,:)
            end
            saveDirName = append(PictureSavePath.path,saveFolderName,"/");
            if ~exist(saveDirName,'dir'), mkdir(saveDirName); end
            obj.allWave(saveDirName,ylim)
        end

        function [] = view(obj,saveFolderName,measuredFreq,ylim)
            arguments
                obj RawDataTwo
                saveFolderName string
                measuredFreq {mustBePositive}
                ylim (1,:)
            end
            saveDirName = append(PictureSavePath.path,saveFolderName,"/");
            if ~exist(saveDirName,'dir'), mkdir(saveDirName); end
            obj.allWave(saveDirName,ylim)
            obj.measuredFreqIsConstCheck(saveDirName,measuredFreq)
        end

        function [] = viewWaveOfFeature(obj,conditionNum,saveFolderName,ylimArray,varAndName)
            arguments
                obj RawDataTwo
                conditionNum {mustBeNumeric,mustBePositive}
                saveFolderName string
                ylimArray (1,:)
                varAndName.featureNum {mustBeNumeric,mustBePositive}=1;
            end
            saveDirName = append(PictureSavePath.path,saveFolderName,"/");
            if ~exist(saveDirName,'dir'), mkdir(saveDirName); end
            figure; hold on
            plot(obj.capacitanceCell{conditionNum}(:,varAndName.featureNum),'.','MarkerSize',4);
            xlabel("Data number"); ylabel("Corrected electrostatic capacity"); xlim([0 inf])
            hold off
            saveas(gcf, append(saveDirName,obj.conditions(conditionNum),"_data.fig"))
            saveas(gcf, append(saveDirName,obj.conditions(conditionNum),"_data.png"))
        end

        function [] = viewFFT(obj, folderName,givenTitle,varAndName)
            arguments
                obj RawDataTwo
                folderName string
                givenTitle string
                varAndName.featureName (1,:) string = string.empty();
                varAndName.minimumLength (1,:) {mustBeNumeric} = 1000;
            end
            featureLength = size(obj.capacitanceCell{1},2);
            for iCondition=1:length(obj.conditions)
                dirName = append(PictureSavePath.path,folderName,obj.conditions(iCondition),"/");
                if ~exist(dirName,'dir'), mkdir(dirName); end
                for iFeature = 1:featureLength
                    figure; hold on
                    
                    % データを取得し、NaNを無視して処理
                    data = rmmissing(obj.capacitanceCell{iCondition}(1:varAndName.minimumLength,iFeature));
                    t_original = obj.timeCell_second{iCondition}(1:length(data)); % 欠損値を除去した後の長さに合わせる
                    t = seconds(t_original)*1000;
                    
                    Y = fft(data);
                    
                    L = length(t);
                    P2 = abs(Y/L);
                    P1 = P2(1:floor(L/2)+1);
                    P1(2:end-1) = 2*P1(2:end-1);
                    f = obj.measuredFreq/L*(0:floor(L/2)); % サンプル数Lを使って周波数軸を計算
                    
                    plot(f,P1,"-k");
                    xlabelobj = xlabel('Frequency Hz');
                    ylabelobj = ylabel('Absolute value of its frequency component');
                    xlabelobj.FontSize=14; ylabelobj.FontSize=14;
                    xlabelobj.FontName='Times New Roman'; ylabelobj.FontName='Times New Roman';
                    
                    % タイトル/サブタイトルの設定
                    if ~isempty(varAndName.featureName)
                        % サブタイトルとファイル名にFeatureNameを使用
                        featureStr = varAndName.featureName(iFeature);
                        subtitle(append("Condition: ", obj.conditions(iCondition),newline,"Feature: ",featureStr));
                    else
                        % タイトルとファイル名にFeature番号を使用
                        featureStr = string(iFeature);
                        title(append(givenTitle," in ", obj.conditions(iCondition)," of Feature ",featureStr),'Units','normalized','Position',[0.5,-0.135,0])
                    end

                    % 保存
                    saveas(gcf, append(dirName,"CondOf",obj.conditions(iCondition),"FeatureOf",featureStr,"_FFT.fig"))
                    saveas(gcf, append(dirName,"CondOf",obj.conditions(iCondition),"FeatureOf",featureStr,"_FFT.png"))
                    
                    hold off
                    close all hidden
                end
            end
        end

        function [] = viewPlotOnly(obj,saveFolderName,ylimArray,varAndName)
            arguments
                obj RawDataTwo
                saveFolderName string
                ylimArray (1,:)
                varAndName.featureNum {mustBeNumeric,mustBePositive}=1
            end
            saveDirName = append(PictureSavePath.path,saveFolderName,"/");
            if ~exist(saveDirName,'dir'), mkdir(saveDirName); end
            for i = 1:length(obj.conditions)
                figure; hold on
                plot(obj.timeCell_second{i},obj.capacitanceCell{i}(:,varAndName.featureNum),'.','MarkerSize',4);
                hold off
                ylim(ylimArray)
                ylabel("Electrostatic capacity F"); xlabel("time s")
                saveas(gcf, append(saveDirName,obj.conditions(i),"AllWave.fig"))
            end
        end
    end

    %% ===== プライベート関数 =====
    methods (Access = private)
        function [] = allWave(obj,saveDirName,ylimArray)
            for i = 1:length(obj.conditions)
                figure; hold on
                plot(obj.timeCell_second{i},obj.capacitanceCell{i})
                
                % representativeはcell arrayなので{}でアクセス
                yline(obj.representative.min{i},'b-',{append("min",string(obj.representative.min{i}))});
                yline(obj.representative.max{i},'r-',{append("max",string(obj.representative.max{i}))});
                yline(obj.representative.average{i},'k-',{append("average",string(obj.representative.average{i}))});
                
                hold off
                ylim(ylimArray)
                ylabel("静電容量 F"); xlabel("時間 s")
                legend(["データ本体","最小値","最大値","平均値"]);
                title(obj.conditions(i),'Units','normalized','Position',[0.5,-0.135,0])
                saveas(gcf, append(saveDirName,obj.conditions(i),"AllWave.fig"))
            end
        end

        function [] = measuredFreqIsConstCheck(obj,saveDirName,measuredFreq)
            for i = 1:length(obj.conditions)
                figure
                plot(diff(obj.timeCell_second{i}),'k-')
                ylabel("前の測定時間との時間の差分 s")
                xlabel("測定番号")
                ylim([seconds(0) seconds(0.05)])
                yline(1/measuredFreq,'r-')
                legend(["測定間隔","適正間隔"])
                title(obj.conditions(i),'Units','normalized','Position',[0.5,-0.135,0])
                saveas(gcf, append(saveDirName,obj.conditions(i),"TimeDelta(For FreqCheck).fig"))
            end
        end

        function representativeTable = createRepresentativeTable(obj,conditions,timeCell,capacitanceCell)
            arguments
                obj RawDataTwo
                conditions (1,:) string
                timeCell (1,:) cell
                capacitanceCell (1,:) cell
            end
            % 代表値の取り出し (NaNを無視)
            timeValue = transpose(cellfun(@numel,timeCell,UniformOutput=false));
            capaValue = transpose(cellfun(@(x) sum(~isnan(x)),capacitanceCell,UniformOutput=false));
            average = transpose(cellfun(@(x) nanmean(x),capacitanceCell,UniformOutput=false)); % nanmeanでNaNを無視して平均
            min = transpose(cellfun(@(x) nanmin(x),capacitanceCell,UniformOutput=false));   % nanminでNaNを無視して最小値
            max = transpose(cellfun(@(x) nanmax(x),capacitanceCell,UniformOutput=false));   % nanmaxでNaNを無視して最大値
            
            % テーブル作成
            condition = transpose(conditions);
            representativeTable = table(condition,timeValue,capaValue,max,min,average);
            
            clear timeValue capaValue average min max
        end
    end
end