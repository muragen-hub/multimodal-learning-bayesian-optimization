classdef RawDataWave < RawData
    % RAWDATAWAVE: RawDataの構造を維持しつつ、VF/Prの波形データと流動様式ラベルを追加したクラス
    
    properties (SetAccess = immutable)
        WaveType % 'VF' (Capacitance) または 'Pr' (Pressure Difference)
        WaveDataCell % 判別に使用する波形データ (セル配列, 例: {Capacitance} または {DifferentialPressure})
        FlowRegimeLabel % 流動様式ラベル (string, 例: "Slug", "Bubbly")
        % (RawDataから継承したプロパティ: timeCell, capacitanceCell などはそのまま利用)
    end
    
    methods (Access = public)
        % コンストラクタ
        function obj = RawDataWave(WaveType, WaveDataCell, FlowRegimeLabel, ...
                                    date, measuredFreq, condition, label, isNeedCorrect, correctCondition, ...
                                    TimeCell, TimeCell_second, CapacitanceCell, LabelCell, LiquidFlowRate, GasFlowRate)
            arguments
                WaveType string % 'VF' or 'Pr'
                WaveDataCell (1,:) cell % 実際の波形データ ({vector} の形式)
                FlowRegimeLabel string % 単一の流動様式ラベル
                
                % RawDataのコンストラクタに渡す引数
                date string
                measuredFreq {mustBePositive}
                condition (1,:) string % 単一の条件 ({'L1G1'} の形式)
                label (1,:) string % 単一のラベル ({'c12a_normal'} の形式)
                isNeedCorrect logical
                correctCondition (1,:) string % 単一の補正条件
                
                % RawDataのセル配列プロパティに対応するデータ
                TimeCell (1,:) cell
                TimeCell_second (1,:) cell
                CapacitanceCell (1,:) cell
                LabelCell (1,:) cell % categorical配列
                LiquidFlowRate (1,:) cell
                GasFlowRate (1,:) cell
            end
            
            % 1. RawDataのコンストラクタを呼び出し (引数はセル配列のまま)
            % RawDataのコンストラクタの引数順: (date, measuredFreq, conditions, labels, isNeedCorrect, correctConditions, timeCell, timeCell_second, capacitanceCell, labelCell, nameAndVar)
            obj = obj@RawData(date, measuredFreq, condition, label, isNeedCorrect, correctCondition, ...
                              TimeCell, TimeCell_second, CapacitanceCell, LabelCell, ...
                              'gasFlowRate', GasFlowRate, ...
                              'liquidFlowRate', LiquidFlowRate);
            
            % 2. RawDataWave固有のプロパティを設定
            obj.WaveType = WaveType;
            obj.WaveDataCell = WaveDataCell; % VFまたはPrの波形データ
            obj.FlowRegimeLabel = FlowRegimeLabel;
        end
    end
end