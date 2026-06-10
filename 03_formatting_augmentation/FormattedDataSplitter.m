classdef FormattedDataSplitter
    %FORMATTEDDATASPLITTER 訓練データとテストデータを同日にしたい時にFormattedDataを適当な割合で分割するクラス
    
    properties
        ratio
    end

    methods(Access = public)
        function obj = FormattedDataSplitter(ratio)
            %FORMATTEDDATASPLITTER このクラスのインスタンスを作成
            obj.ratio = ratio;
        end

        function [formattedData1, formattedData2] = split(obj,formattedData)
            arguments
                obj FormattedDataSplitter
                formattedData FormattedData
            end
            conditionsLength = length(formattedData.condition);

            data_1 = cell(1, conditionsLength);
            label_1 = cell(1, conditionsLength);
            data_2 = cell(1, conditionsLength);
            label_2 = cell(1, conditionsLength);

            averageTmp_1 = cell(1,conditionsLength);
            averageTmp_2 = cell(1,conditionsLength);
            maxTmp_1 = cell(1,conditionsLength);
            maxTmp_2 = cell(1, conditionsLength);
            minTmp_1 = cell(1, conditionsLength);
            minTmp_2 = cell(1, conditionsLength);

            liquidFlowRateOfEachData_1= cell.empty();
            liquidFlowRateOfEachData_2= cell.empty();
            gasFlowRateOfEachData_1 = cell.empty();
            gasFlowRateOfEachData_2 = cell.empty();
            if(~isempty(formattedData.liquidFlowRateOfEachData))
                liquidFlowRateOfEachData_1= cell(1, conditionsLength);
                liquidFlowRateOfEachData_2= cell(1, conditionsLength);
                gasFlowRateOfEachData_1 = cell(1, conditionsLength);
                gasFlowRateOfEachData_2 = cell(1, conditionsLength);
            end

            for i = 1:conditionsLength
                n = size(formattedData.capacitanceCell{i},1);
                hpartition = cvpartition(n,'Holdout',obj.ratio); % Nonstratified partition
                idxTrain = training(hpartition);
                data_1{i} = formattedData.capacitanceCell{i}(idxTrain,:,:);
                label_1{i} = formattedData.labelCell{i}(idxTrain,:);
                averageTmp_1{i} = formattedData.average{i}(idxTrain,:,:);
                maxTmp_1{i} = formattedData.max{i}(idxTrain,:,:);
                minTmp_1{i} = formattedData.min{i}(idxTrain,:,:);
                if(~isempty(formattedData.liquidFlowRateOfEachData))
                    liquidFlowRateOfEachData_1{i} = formattedData.liquidFlowRateOfEachData{i}(idxTrain,:);
                    gasFlowRateOfEachData_1{i} = formattedData.gasFlowRateOfEachData{i}(idxTrain,:);
                end

                idxTest = test(hpartition);
                data_2{i} = formattedData.capacitanceCell{i}(idxTest,:,:);
                label_2{i} = formattedData.labelCell{i}(idxTest,:);
                averageTmp_2{i} = formattedData.average{i}(idxTest,:);
                maxTmp_2{i} = formattedData.max{i}(idxTest,:);
                minTmp_2{i} = formattedData.min{i}(idxTest,:);
                if(~isempty(formattedData.liquidFlowRateOfEachData))
                    liquidFlowRateOfEachData_2{i} = formattedData.liquidFlowRateOfEachData{i}(idxTest,:);
                    gasFlowRateOfEachData_2{i} = formattedData.gasFlowRateOfEachData{i}(idxTest,:);
                end
            end
            formattedData2 = FormattedData(formattedData.option,formattedData.date,formattedData.condition,formattedData.label,data_1,label_1,averageTmp_1,maxTmp_1,minTmp_1,"liquidFlowRateOfEachData",liquidFlowRateOfEachData_1,"gasFlowRateOfEachData",gasFlowRateOfEachData_1); % 逆だが修正が面倒なのでそのまま.
            formattedData1 = FormattedData(formattedData.option,formattedData.date,formattedData.condition,formattedData.label,data_2,label_2,averageTmp_2,maxTmp_2,minTmp_2,"liquidFlowRateOfEachData",liquidFlowRateOfEachData_2,"gasFlowRateOfEachData",gasFlowRateOfEachData_2);
        end

        function [formattedData1, formattedData2] = multiVectorSplit(obj,formattedData)
            arguments
                obj FormattedDataSplitter
                formattedData FormattedData
            end

            conditionsLength = length(formattedData.condition);

            data_1 = cell(1, conditionsLength);
            label_1 = cell(1, conditionsLength);
            data_2 = cell(1, conditionsLength);
            label_2 = cell(1, conditionsLength);

            averageTmp_1 = cell(1,conditionsLength);
            averageTmp_2 = cell(1,conditionsLength);
            maxTmp_1 = cell(1,conditionsLength);
            maxTmp_2 = cell(1, conditionsLength);
            minTmp_1 = cell(1, conditionsLength);
            minTmp_2 = cell(1, conditionsLength);

            for i = 1:conditionsLength
                n = length(formattedData.capacitanceCell{i});
                hpartition = cvpartition(n,'Holdout',obj.ratio); % Nonstratified partition
                idxTrain = training(hpartition);
                data_1{i} = formattedData.capacitanceCell{i}(idxTrain,:,:);
                label_1{i} = formattedData.labelCell{i}(idxTrain,:,:);
                averageTmp_1{i} = formattedData.average{i}(idxTrain,:,:);
                maxTmp_1{i} = formattedData.max{i}(idxTrain,:,:);
                minTmp_1{i} = formattedData.min{i}(idxTrain,:,:);

                idxTest = test(hpartition);
                data_2{i} = formattedData.capacitanceCell{i}(idxTest,:,:);
                label_2{i} = formattedData.labelCell{i}(idxTest,:,:);
                averageTmp_2{i} = formattedData.average{i}(idxTest,:,:);
                maxTmp_2{i} = formattedData.max{i}(idxTest,:,:);
                minTmp_2{i} = formattedData.min{i}(idxTest,:,:);
            end
            formattedData2 = FormattedData(formattedData.option,formattedData.date,formattedData.condition,formattedData.label,data_1,label_1,averageTmp_1,maxTmp_1,minTmp_1);
            formattedData1 = FormattedData(formattedData.option,formattedData.date,formattedData.condition,formattedData.label,data_2,label_2,averageTmp_2,maxTmp_2,minTmp_2);
        end

    end
end

