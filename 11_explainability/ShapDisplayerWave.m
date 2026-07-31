classdef ShapDisplayerWave
    %SHAPDISPLAYERWAVE Wave系(VF/Pr)SHAP結果をクラス×特徴量のヒートマップとして可視化する.
    %   ShapDisplayer (モダリティ単位, 3固定列) とは別に, チャンネル単位(2特徴量)・
    %   統計量ベース(5特徴量)のどちらにも使えるよう特徴量数を可変にしたクラス.

    methods (Access = public, Static)
        function [] = displayClassWiseHeatmap(meanAbsShap, featureNames, classNames, folderName, nameAndVar)
            % クラス×特徴量の平均|Shapley値|をヒートマップ表示・保存する
            arguments
                meanAbsShap (:,:) double
                featureNames (1,:) string
                classNames (1,:) string
                folderName string
                nameAndVar.fileName string = "ShapleyValues_ClassWise"
                nameAndVar.figTitle string = "クラス別 平均|Shapley値|"
            end

            dirName = append(PictureSavePath.path, folderName, "/");
            if ~exist(dirName, 'dir')
                mkdir(dirName)
            end

            figure
            heatmap(featureNames, classNames, meanAbsShap);
            xlabel("特徴量")
            ylabel("流動様式")
            title(nameAndVar.figTitle)
            saveas(gcf, append(dirName, nameAndVar.fileName, ".fig"))
        end
    end
end
