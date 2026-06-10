classdef DataFormatterCreatorTwo
    %FORMATTEDDATA 深層学習用に, 実験生データを整えたデータを格納するクラスのためのファクトリー作成のためのクラス

    properties (SetAccess = immutable)
        option
    end

    methods (Access = public)
        function obj = DataFormatterCreatorTwo(option)
            arguments
                option DataFormatterOption
            end
            obj.option = option;


        end
        function dataFormatter = create(obj)
            arguments
                obj DataFormatterCreatorTwo
            end
            dataFormatter = DataFormatterTwo(obj.option);
        end
    end
end




