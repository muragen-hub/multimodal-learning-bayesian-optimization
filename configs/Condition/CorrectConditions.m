classdef CorrectConditions
       %CONDITIONS　どの条件で補正を施すかを記述 MATLABがだめだめでstatic readonlyできないので書き換えに注意
       %　また, 恐らく気相の途中で補正用の数値を取得するほどに気相条件を細かくすることは多分ないと思うので, 全て液相条件で記します.
       %　今後大流量化するとかの話も出てますので.
    
    properties (Constant) 
        LiquidPureFlowPrefix = "G30_before_";
        gasPreFlowSuffix = "G0";

        c22_liquidChange = ["L6"  "L6" "L6" "L6" "L6" "L6" "L6" "L6" "L6" "L6" "L6" "L3"  "L3" "L3" "L3" "L3" "L3" "L3" "L3" "L3" "L3" "L3"];
        c12_liquidChange = ["L1.5" "L1.5" "L1.5" "L3" "L3" "L3" "L4.5" "L4.5" "L4.5" "L6" "L6" "L6"];
        c9_liquidChange = ["L1.5" "L1.5" "L1.5" "L3" "L3" "L3" "L4.5" "L4.5" "L4.5"];
        c11_liquidChange = ["L1.5" "L1.5" "L1.5" "L3" "L3" "L3" "L4.5" "L4.5" "L4.5" "L6" "L6" ];
        test = ["L3" "L3" "L3"];
        c28_liquidChange = ["L0.5" "L0.5" "L0.5" "L0.5" "L0.7" "L0.7" "L0.7" "L0.7" "L1" "L1" "L1" "L1" "L3" "L3" "L3" "L3" "L6" "L6" "L6" "L6" "L10" "L10" "L10" "L10" "L14" "L14" "L14" "L14"];
        plugSlug_28 = ["L3" "L3" "L3" "L6" "L6" "L6" ];
        c12a_liquidChange = ["L0.05" "L0.05" "L0.05" "L1" "L1" "L2" "L3" "L3" "L3" "L5" "L5" "L6"];
    end
end

