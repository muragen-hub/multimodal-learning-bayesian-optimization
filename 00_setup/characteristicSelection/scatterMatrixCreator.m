classdef scatterMatrixCreator
    %SCATTERMATRIXCREATOR scattermatrixを作る関数. Econometrics Toolboxが必要です. (関数corrplot使用)
    
    properties(SetAccess=immutable)
        option (1,:) scatterMatrixOption
        dataLengthLimitPerCondition {mustBePositive,mustBeInteger}
    end
    
    methods
        function obj = scatterMatrixCreator(givenOption, givenDataLengthLimitPerCondition)
            arguments
                givenOption scatterMatrixOption
                givenDataLengthLimitPerCondition {mustBePositive,mustBeInteger}
            end
            %SCATTERMATRIXCREATOR このクラスのインスタンスを作成
            obj.option = givenOption;
            obj.dataLengthLimitPerCondition =  givenDataLengthLimitPerCondition;
        end
        
        function [] = createMatrix(obj,folderName)
            arguments
                obj scatterMatrixCreator
                folderName string
            end
            dirName = append(PictureSavePath.path,folderName);
            if not(exist( dirName ,'dir'))
                mkdir( dirName )
            end
            dirName_accurateLiquidVS = append(PictureSavePath.path,folderName,"VSAccurateLiquid/");
            if not(exist( dirName_accurateLiquidVS ,'dir'))
                mkdir( dirName_accurateLiquidVS )
            end

            [featureMatrixCell, integratedMatrix, varNames] = obj.createEachFeatureMatrix();
            [featureMatrixCell_liquid, integratedMatrix_liquid] = createAccurateLiquidFlowRateMatrix(obj);
            % 全体の場合の特徴量相関係数図
            figure;
            corrplot(integratedMatrix,VarNames=varNames);
            conditionsLength = length(obj.option(1).rawData(1).conditions);
            disp("fin of integrated matrix");
            saveas(gcf, append(dirName,"TotalScatterPlotMatrix", ".fig"));
            %正確な流量との相関についての図．
            featureNum = length(varNames);

            for iFeature = 1:featureNum
            figure;
            % [TODO] ここってピアソンの相関係数以外だとどうなるんだろうね．
            corr = corrcoef(integratedMatrix(:,iFeature),integratedMatrix_liquid);
            hold on;
            scatter(integratedMatrix(:,iFeature),integratedMatrix_liquid,3,"black","filled");
 
            % 時間切れ最小二乗法で直線出せれば良かったんだけど，lsqr関数の戻り値がよくわからなかった．
            %lineofLS = lsqr(integratedMatrix(:,iFeature),integratedMatrix_liquid);            
            %xlimit = [min(integratedMatrix(:,iFeature)) max(integratedMatrix(:,iFeature))];
            %ylimit = [min(integratedMatrix_liquid),max(integratedMatrix_liquid)];
            %xlim(xlimit);
            %ylim(ylimit);
            subtitle(append("Correlation (Pearson): ",string(corr(1,2))));

            xlabelobj = xlabel(append(varNames(iFeature)," value (Standardized)"));
            xlabelobj.FontSize = 14;
            xlabelobj.FontName = 'Times New Roman';
            ylabelobj = ylabel("Accurate liquid flow rate L/min");
            ylabelobj.FontSize = 14;
            ylabelobj.FontName = 'Times New Roman';
            hold off;
            saveString = append("AccurateLiquidVS",varNames(iFeature));
            saveas(gcf, append(dirName_accurateLiquidVS,saveString, ".fig"));
            saveas(gcf, append(dirName_accurateLiquidVS,saveString, ".png"));
            end
            close all hidden;
            %各conditionごとの場合の相関係数図
            for iCondition = 1:conditionsLength
                figure;
                corrplot(featureMatrixCell{iCondition},VarNames=varNames);
                disp("fin of condition"+string(obj.option(1).rawData(1).conditions(iCondition)));
                saveas(gcf, append(dirName,"ScatterPlotMatrixOf",string(obj.option(1).rawData(1).conditions(iCondition)),".fig"));

                dirName_accurateLiquidVS = append(PictureSavePath.path,folderName,"VSAccurateLiquid/",string(obj.option(1).rawData(1).conditions(iCondition)),"/");
                if not(exist( dirName_accurateLiquidVS ,'dir'))
                    mkdir(dirName_accurateLiquidVS )
                end

                for iFeature = 1:featureNum
                figure;
                hold on;
                scatter(featureMatrixCell{iCondition}(:,iFeature),featureMatrixCell_liquid{iCondition},3,"black","filled");
                corr = corrcoef(featureMatrixCell{iCondition}(:,iFeature),featureMatrixCell_liquid{iCondition});
                subtitle(append("Correlation (Pearson): ",string(corr(1,2))));
                xlabelobj = xlabel(append(varNames(iFeature)," value (Standardized)"));
                xlabelobj.FontSize = 14;
                xlabelobj.FontName = 'Times New Roman';
                ylabelobj = ylabel("Accurate liquid flow rate L/min");
                ylabelobj.FontSize = 14;
                ylabelobj.FontName = 'Times New Roman';
                hold off;
                saveString = append("AccurateLiquidVS",varNames(iFeature));
                saveas(gcf, append(dirName_accurateLiquidVS,saveString, ".fig"));
                saveas(gcf, append(dirName_accurateLiquidVS,saveString, ".png"));
                end
                close all hidden;
            end
        end

        function [] = viewEachFeaturePlot(obj)
            arguments
                obj scatterMatrixCreator
            end
            featureMatrixCell = obj.createEachFeatureMatrix();
            conditionLength = length(featureMatrixCell);
            featureLength = size(featureMatrixCell{1},2);
            for iCondition = 1:conditionLength
                figure;
                for iFeature = 1:featureLength
                hold on
                plot(featureMatrixCell{iCondition}(:,iFeature));
                hold off
                legend
                end
            end
        end
    end

    methods (Access = private)
        % featureMatrixCell: 条件ごとにセルで区切ったやつ
        % integratedMatrix : セルで区切らず全て一つにしたやつ(corr関数の入力条件)
        function [featureMatrixCell, integratedMatrix,featureNames] = createEachFeatureMatrix(obj)
            arguments
                obj scatterMatrixCreator
            end
            % 仮定: すべてのRawDataの実験条件は同じである. 
            % rawDataの内部の数を合わせないとエラーを出す. 
            %branchingFuncでrawDataの中身の数を合わせるようなものを作って, この関数を使う前に置いておく. 
            optionLength = length(obj.option);
            %optionの数だけ回して最後に並列に結合
            for iOption = 1:optionLength
                thatOptionRawDataArray = obj.option(iOption).rawData;
                rawDataLength = length(thatOptionRawDataArray);
                conditionLength = length(thatOptionRawDataArray(1).conditions);
                
                tmpCapacitanceOfAllRawData = cell(1,conditionLength);
                % RawData間での各conditionデータをすべてまとめる各conditionのデータ長をdataLengthLimitPerConditionにそろえる.
                % dataLengthLimitPerConditionが最小長さを上回っていた場合にエラー出す. (データ長そろわないので)
                % 最小データ長拾ってくる. 
                minLength = inf; 
                for iRawData = 1: rawDataLength
                    for iCondition = 1:conditionLength
                        tmpLength = size(thatOptionRawDataArray(iRawData).capacitanceCell{iCondition},1);
                        if tmpLength < minLength
                            minLength = tmpLength;
                        end
                        if minLength < obj.dataLengthLimitPerCondition
                            error('条件ごとのデータの最小のデータ数は　%i ですが, 揃えるためのパラメータであるdataLengthLimitPerConditionは %i で大きすぎます. RawDataの日付は %s です(loop index = %i)', minLength,obj.dataLengthLimitPerCondition,thatOptionRawDataArray(iRawData).date,iOption )
                        end
                        % 各conditionのデータ数を揃えて, 複数RawData間のデータを統合. 
                        tmpCapacitanceOfAllRawData{iCondition} = vertcat(tmpCapacitanceOfAllRawData{iCondition}, thatOptionRawDataArray(iRawData).capacitanceCell{iCondition}(1:obj.dataLengthLimitPerCondition,:));
                    end
                end
                if iOption == 1
                    featureMatrixCell = tmpCapacitanceOfAllRawData; %tmpCapacitanceOfAllRawData{1};
                else
                    for iCondition = 1:conditionLength
                    featureMatrixCell{iCondition} = horzcat(featureMatrixCell{iCondition},tmpCapacitanceOfAllRawData{iCondition}); %#ok option数が膨大になることはないので. ここのループ反復による配列サイズの再構成は気にする必要はない. 
                    end
                end
                
                % これやっているため上のifと下のifは統合できない. 
                % まずintegratedをつくるために全条件を{1}へ統合
                for iCondition =2:conditionLength
                    tmpCapacitanceOfAllRawData{1} = vertcat(tmpCapacitanceOfAllRawData{1},tmpCapacitanceOfAllRawData{iCondition});
                end 
                % 次にoption間で統合する．
                if iOption == 1
                    integratedMatrix  = tmpCapacitanceOfAllRawData{1}; %tmpCapacitanceOfAllRawData{1};
                else
                    integratedMatrix = horzcat(integratedMatrix,tmpCapacitanceOfAllRawData{1}); %#ok option数が膨大になることはないので. ここのループ反復による配列サイズの再構成は気にする必要はない. 
                end
                integratedMatrix = zscore(integratedMatrix);
                % 名前をまとめる. 
                if iOption == 1
                    featureNames = obj.option(iOption).characteristicName;
                else
                    featureNames = horzcat(featureNames,obj.option(iOption).characteristicName); %#ok option数が膨大になることはないので. ここのループ反復による配列サイズの再構成は気にする必要はない. 
                end
                
            end

            % 条件ごとのほうを特徴量ごとに標準化. 標準化しても相関係数には影響はない
            for iCondition = 1:conditionLength
            featureMatrixCell{iCondition} = zscore(featureMatrixCell{iCondition});
            end
        end

        % featureMatrixCell: 条件ごとにセルで区切ったやつ
        % integratedMatrix : セルで区切らず全て一つにしたやつ(corr関数の入力条件)
        function [featureMatrixCell, integratedMatrix] = createAccurateLiquidFlowRateMatrix(obj)
            arguments
                obj scatterMatrixCreator
            end
            % 仮定: すべてのRawDataの実験条件は同じである. 
            % rawDataの内部の数を合わせないとエラーを出す. 
            %branchingFuncでrawDataの中身の数を合わせるようなものを作って, この関数を使う前に置いておく. 
            optionLength = length(obj.option);
            %optionの数だけ回して最後に並列に結合
            for iOption = 1:optionLength
                thatOptionRawDataArray = obj.option(iOption).rawData;
                rawDataLength = length(thatOptionRawDataArray);
                conditionLength = length(thatOptionRawDataArray(1).conditions);
                
                tmpLiquidFlowRateOfAllRawData = cell(1,conditionLength);
                % RawData間での各conditionデータをすべてまとめる各conditionのデータ長をdataLengthLimitPerConditionにそろえる.
                % dataLengthLimitPerConditionが最小長さを上回っていた場合にエラー出す. (データ長そろわないので)
                % 最小データ長拾ってくる. 
                minLength = inf; 
                for iRawData = 1: rawDataLength
                    for iCondition = 1:conditionLength
                        tmpLength = size(thatOptionRawDataArray(iRawData).capacitanceCell{iCondition},1);
                        if tmpLength < minLength
                            minLength = tmpLength;
                        end
                        if minLength < obj.dataLengthLimitPerCondition
                            error('条件ごとのデータの最小のデータ数は　%i ですが, 揃えるためのパラメータであるdataLengthLimitPerConditionは %i で大きすぎます. RawDataの日付は %s です(loop index = %i)', minLength,obj.dataLengthLimitPerCondition,thatOptionRawDataArray(iRawData).date,iOption )
                        end
                        % 各conditionのデータ数を揃えて, 複数RawData間のデータを統合. 
                        tmpLiquidFlowRateOfAllRawData{iCondition} = vertcat(tmpLiquidFlowRateOfAllRawData{iCondition}, thatOptionRawDataArray(iRawData).liquidFlowRate{iCondition}(1:obj.dataLengthLimitPerCondition,:));
                    end
                end
                % 流量はoption間で一つなのでこれで良い．
                featureMatrixCell = tmpLiquidFlowRateOfAllRawData;
                
                % これやっているため上のifと下のifは統合できない. 
                for iCondition =2:conditionLength
                    tmpLiquidFlowRateOfAllRawData{1} = vertcat(tmpLiquidFlowRateOfAllRawData{1},tmpLiquidFlowRateOfAllRawData{iCondition});
                end 
                % 流量はoption間で一つなのでこれで良い．
                integratedMatrix  = tmpLiquidFlowRateOfAllRawData{1};
            end
        end
    end
end

