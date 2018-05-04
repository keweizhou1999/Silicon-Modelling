function sparams = getVoltagePulse( sparams, xx )
%GETVOLTAGEPULSE Summary of this function goes here
%   Detailed explanation goes here

    % The idea behind this function is to generate a pulsing sequence for
    % all the gates we have control over in our geometry.
    % We simply define each pulsing sequence according to percentage of the
    % total time.  For now, we use a grid of 100 points.  So we have
    % accuracy of our control pulses to within 1% of our total time.  This
    % is easily adjustable if we need in the future.
    
    sparams.voltagePulse = zeros(sparams.numOfGates,101);
    
    % Now, we wish to find what value the second gate needs to be so that
    % the tunnel coupling is maximal.  Due to cross capacitances, setting
    % V1 = V2 does not actually mean the detuning is 0.  This short segment
    % finds that value
    scaleFactor = 1000;

    % Let's do the first part of the sweep
    g1Max = 0.8;
    g1Min = 0.6;
    g2Min = 0.6;
    g3Max = 0.8;
    g3Min = 0.6;
    ratio = 0.990;
    
    [g2Max, ~] = fminbnd(@(x) findMinDeltaE(x),.7*scaleFactor,1.02*scaleFactor);
    g2Max = g2Max/scaleFactor;
    function deltaE = findMinDeltaE(g2)
        g2 = g2/scaleFactor;
        currPot = squeeze(sparams.P2DEGInterpolant({g1Max,g2,g3Min,xx}));
            
        peaks = sort(findpeaks(-currPot),'descend');
        deltaE = (peaks(1) - peaks(2))/sparams.ee;         
    end
    
    ind = 1:3;
    gate1p = ones(1,length(ind))*g1Max;
    gate2p = linspace(g2Min,g2Max*ratio,length(ind));
    gate3p = ones(1,length(ind))*g3Min;
    
    ind = 3:26;
    temp1 = ones(1,length(ind))*g1Max;
    temp2 = linspace(g2Max*ratio,g2Max,length(ind));
    temp3 = ones(1,length(ind))*g3Min;
    gate1p = [gate1p, temp1(2:end)];
    gate2p = [gate2p, temp2(2:end)];
    gate3p = [gate3p, temp3(2:end)];
    
    ind = 26:49;
    temp1 = linspace(g1Max,g1Max*ratio,length(ind));
    temp2 = ones(1,length(ind))*g2Max;
    temp3 = ones(1,length(ind))*g3Min;
    gate1p = [gate1p, temp1(2:end)];
    gate2p = [gate2p, temp2(2:end)];
    gate3p = [gate3p, temp3(2:end)];
    
    ind = 49:51;
    temp1 = linspace(g1Max*ratio,g1Min,length(ind));
    temp2 = ones(1,length(ind))*g2Max;
    temp3 = ones(1,length(ind))*g3Min;
    gate1p = [gate1p, temp1(2:end)];
    gate2p = [gate2p, temp2(2:end)];
    gate3p = [gate3p, temp3(2:end)];
    
    ind = 51:53;
    temp1 = ones(1,length(ind))*g1Min;
    temp2 = ones(1,length(ind))*g2Max;
    temp3 = linspace(g3Min,g3Max*ratio,length(ind));
    gate1p = [gate1p, temp1(2:end)];
    gate2p = [gate2p, temp2(2:end)];
    gate3p = [gate3p, temp3(2:end)];
    
    ind = 53:76;
    temp1 = ones(1,length(ind))*g1Min;
    temp2 = ones(1,length(ind))*g2Max;
    temp3 = linspace(g3Max*ratio,g3Max,length(ind));
    gate1p = [gate1p, temp1(2:end)];
    gate2p = [gate2p, temp2(2:end)];
    gate3p = [gate3p, temp3(2:end)];
    
    ind = 76:98;
    temp1 = ones(1,length(ind))*g1Min;
    temp2 = linspace(g2Max,g2Max*ratio,length(ind));
    temp3 = ones(1,length(ind))*g3Max;
    gate1p = [gate1p, temp1(2:end)];
    gate2p = [gate2p, temp2(2:end)];
    gate3p = [gate3p, temp3(2:end)];
    
    ind = 98:100;
    temp1 = ones(1,length(ind))*g1Min;
    temp2 = linspace(g2Max*ratio,g2Min,length(ind));
    temp3 = ones(1,length(ind))*g3Max;
    gate1p = [gate1p, temp1(2:end)];
    gate2p = [gate2p, temp2(2:end)];
    gate3p = [gate3p, temp3(2:end)];
    
    gate1p = [gate1p, g1Min];
    gate2p = [gate2p, g2Min];
    gate3p = [gate3p, g3Max];
    
    sparams.voltagePulse(1,:) = gate1p;
    sparams.voltagePulse(2,:) = gate2p;
    sparams.voltagePulse(3,:) = gate3p;
end










