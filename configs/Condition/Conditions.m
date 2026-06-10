classdef Conditions 
    %CONDITIONS　実験条件を羅列した静的クラス MATLABがだめだめでstatic readonlyできないので書き換えに注意
    %行った実験の条件を示す. 
    
    properties (Constant) 
        c22 = ["L6G1"  "L6G5" "L6G10" "L6G15" "L6G20" "L6G25" "L6G30" "L6G35" "L6G40" "L6G45" "L6G50" "L3G1"  "L3G5" "L3G10" "L3G15" "L3G20" "L3G25" "L3G30" "L3G35" "L3G40" "L3G45" "L3G50"];
        c12 = ["L1.5G1" "L1.5G25" "L1.5G50" "L3G1" "L3G25" "L3G50" "L4.5G1" "L4.5G25" "L4.5G50" "L6G1" "L6G25" "L6G50"];
        c9 = ["L1.5G1" "L1.5G25" "L1.5G50" "L3G1" "L3G25" "L3G50" "L4.5G1" "L4.5G25" "L4.5G50"] %20221209とかはL6が出ていない.
        c11 = ["L1.5G1" "L1.5G25" "L1.5G50" "L3G1" "L3G25" "L3G50" "L4.5G1" "L4.5G25" "L4.5G50" "L6G1" "L6G25" ]; %L6の中でも特に6L/minが出ておらず, 5.4L/minくらいでやばかったデータを除去した場合(2021年実験)
        c6 = ["L3G1" "L3G25" "L3G50" "L6G1" "L6G25" "L6G50"];
        test = ["L3G1" "L3G25" "L3G50"];
        c28 = ["L0.5G1" "L0.5G3" "L0.5G20" "L0.5G70" "L0.7G1" "L0.7G3" "L0.7G20" "L0.7G70" "L1G1" "L1G3" "L1G20" "L1G70" "L3G1" "L3G3" "L3G20" "L3G70" "L6G1" "L6G3" "L6G20" "L6G70" "L10G1" "L10G3" "L10G20" "L10G70" "L14G1" "L14G3" "L14G20" "L14G70"];
        c28a = ["L0.5G1" "L0.5G3" "L0.5G20" "L0.5G70" "L0.7G1" "L0.7G3" "L0.7G20" "L0.7G70" "L1G1" "L1G3" "L1G20" "L1G70" "L3G1" "L3G3" "L3G20" "L3G70" "L6G1" "L6G3" "L6G20" "L6G70" "L10G1" "L10G3" "L10G20" "L10G70" "L14G1" "L14G3" "L14G20" "L14G50"];
        c30 = ["L0.05G1" "L0.05G53" "L0.5G1" "L0.5G3" "L0.5G20" "L0.5G70" "L0.7G1" "L0.7G3" "L0.7G20" "L0.7G70" "L1G1" "L1G3" "L1G20" "L1G70" "L3G1" "L3G3" "L3G20" "L3G70" "L6G1" "L6G3" "L6G20" "L6G70" "L10G1" "L10G3" "L10G20" "L10G70" "L14G1" "L14G3" "L14G20" "L14G50"];
        plugSlug_28 = ["L3G1" "L3G3" "L3G20" "L6G1" "L6G3" "L6G20" ];
        flowRegimes = ["Stratified" "Bubbly" "Slug" "Plug" "Annular"];
        c12a = ["L0.05G1" "L0.05G3" "L0.05G10" "L1G3" "L1G90" "L2G20" "L3G3" "L3G20" "L3G90" "L5G20" "L5G90" "L6G1"];
    end
end

