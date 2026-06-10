classdef DataFormatterCreatorWave
    % DATAFORMATTERCREATORWAVE: 
    % DataFormatterOptionWaveを受け取り、DataFormatterWaveのインスタンスを生成するファクトリクラス。
    
    properties (SetAccess = immutable)
        option
    end
    
    methods (Access = public)
        function obj = DataFormatterCreatorWave(option)
            arguments
                option DataFormatterOptionWave % ★ 新しいオプションクラスを使用
            end
            obj.option = option;
        end
        
        function dataFormatter = create(obj)
            arguments
                obj DataFormatterCreatorWave
            end
            % DataFormatterWave クラスのインスタンスを生成
            dataFormatter = DataFormatterWave(obj.option); % ★ 新しいDataFormatter本体クラスを使用
        end
    end
end