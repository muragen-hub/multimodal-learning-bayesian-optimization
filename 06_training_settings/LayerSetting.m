classdef LayerSetting
    %LAYERSETTING 層の構成

    properties (SetAccess = immutable)
        layer
    end

    methods (Access = public)
        function obj = LayerSetting(layer)
            obj.layer = layer;
        end
    end
end

