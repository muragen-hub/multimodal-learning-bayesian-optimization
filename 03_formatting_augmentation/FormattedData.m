classdef FormattedData
    %FORMATTEDDATA 訓練とテストに備えてformatOptionに定められた形式に修正されたデータ
    %   詳細説明をここに記述

    properties
        option DataFormatterOption
        date string
        condition (1,:) string
        label (1,:) string
        capacitanceCell (:,:) cell
        labelCell (1,:) cell
        average (:,:)
        max (:,:)
        min (:,:)
        liquidFlowRateOfEachData (1,:) cell
        gasFlowRateOfEachData (1,:) cell
    end

    methods
        function obj = FormattedData(option,date,condition,label, capacitanceCell, labelCell, average, max,min,nameAndVar)
            arguments
                option DataFormatterOption
                date string
                condition (1,:) string
                label (1,:) string
                capacitanceCell (:,:) cell
                labelCell (1,:) cell
                average (:,:) cell
                max (:,:) cell
                min (:,:) cell
                nameAndVar.liquidFlowRateOfEachData (1,:) cell = cell.empty();
                nameAndVar.gasFlowRateOfEachData (1,:) cell = cell.empty();
            end
            obj.option = option;
            obj.date = date;
            obj.condition = condition;
            obj.label = label;
            obj.capacitanceCell = capacitanceCell;
            obj.labelCell = labelCell;
            obj.average = average;
            obj.max = max;
            obj.min = min;
            obj.liquidFlowRateOfEachData = nameAndVar.liquidFlowRateOfEachData;
            obj.gasFlowRateOfEachData = nameAndVar.gasFlowRateOfEachData;
        end

        function [] = viewDataUniformity(obj,saveFolderName)
            arguments
                obj FormattedData
                saveFolderName string
            end
            saveDirName = append( PictureSavePath.path,saveFolderName,"/");
            if not(exist( saveDirName ,'dir'))
                mkdir( saveDirName )
            end
            
            % x点を集めたデータの平均値, 最大, 最小のばらつきを見る.
            catagoricalCondition = categorical(obj.condition);
            figure;
            hold on
            for i = 1:length(catagoricalCondition)
                boxchart(obj.labelCell{1,i}, obj.average{1,i});
            end
            hold off
            legend(obj.condition,'Location','northeastoutside');
            ylabel("静電容量値 F")
            title("平均値のばらつき",'Units', 'normalized', 'Position', [0.5, -0.135, 0]);
            saveas(gcf, append(saveDirName,"averageSigma.fig"))
            
            figure;
            hold on;
            for i = 1:length(catagoricalCondition)
                boxchart(obj.labelCell{1,i}, obj.max{1,i});
            end
            hold off;
            legend(obj.condition,'Location','northeastoutside');
            ylabel("静電容量値 F")
            title("最大値のばらつき",'Units', 'normalized', 'Position', [0.5, -0.135, 0]);
            saveas(gcf, append(saveDirName,"maxSigma.fig"))
            
            figure;
            hold on;
            for i = 1:length(catagoricalCondition)
                boxchart(obj.labelCell{1,i}, obj.min{1,i});
            end
            hold off;
            legend(obj.condition,'Location','northeastoutside');
            ylabel("静電容量値 F")
            title("最小値のばらつき",'Units', 'normalized', 'Position', [0.5, -0.135, 0]);
            saveas(gcf, append(saveDirName,"minSigma.fig"))

             % R値の棒グラフ
            x = categorical(length(catagoricalCondition),1);
            y = zeros(length(catagoricalCondition),1);
            for i = 1:length(catagoricalCondition)
                x(i) = obj.labelCell{1,i}(1);
                y(i) = var(obj.average{1,i});
            end
            figure;
            hold on
            bar(x,y,0.4);
            hold off
            ylabel("分散")
            title("平均値のばらつき(分散)",'Units', 'normalized', 'Position', [0.5, -0.135, 0]);
            saveas(gcf, append(saveDirName,"averageSigma_R.fig"))
        end

        function [] = viewDataInNumberOf(obj,conditionNum,number,saveFolderName,ylimArray,varAndName)
            arguments
                obj FormattedData
                conditionNum {mustBeNumeric,mustBePositive}
                number {mustBeNumeric,mustBePositive}
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
            if number ~=inf
            plot(obj.capacitanceCell{conditionNum}(number,1:end,varAndName.featureNum),'.','MarkerSize',4);
            else
            plot(obj.capacitanceCell{conditionNum}(end,1:end,varAndName.featureNum),'.','MarkerSize',4);  
            end
            xlabel("Data number");
            ylabel("Corrected electrostatic capacity");
            ylim(ylimArray)
            xlim([0 inf])
            hold off;
            saveas(gcf, append(saveDirName,string(number),"dataOf",string(obj.condition(conditionNum)),".fig"))
        end
    end
end

