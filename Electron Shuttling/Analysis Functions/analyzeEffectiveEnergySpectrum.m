function analyzeEffectiveEnergySpectrum(sparams, effHamParams, variedVariable,...
    dataTypeToPlot, colorRange)
%ANALYZEEFFECTIVEENERGYSPECTRUM Summary of this function goes here
%   Detailed explanation goes here

    colorAxisVariable = dataTypeToPlot{1};
    colorAxisAxis = dataTypeToPlot{2};
    linewidth = 2;
    
    switch lower(variedVariable)
        case 'detuning'
            variedData = effHamParams{1} - effHamParams{2};
            effHamParams{1} = effHamParams{1}(1);
            effHamParams{2} = effHamParams{2}(1);
        otherwise
            error('Incorrect input for the varied variable argument.');
    end

    nPts = length(variedData);
    nStates = 1;
    if sparams.includeOrbital
        nStates = 2*nStates;
    end
    if sparams.includeValley
        nStates = 2*nStates;
    end
    if sparams.includeSpin
        nStates = 2*nStates;
    end
    if sparams.includeSecondSpin
        nStates = 2*nStates;
    end   
    
    energies = zeros(nStates,nPts);
    for ii = 1:nPts
        if ii ~= 1
            switch lower(variedVariable)
                case 'detuning'
                    effHamParams{1} = effHamParams{1} + (variedData(ii) - variedData(ii-1))/2;
                    effHamParams{2} = effHamParams{2} - (variedData(ii) - variedData(ii-1))/2;
            end 
        end

        Heff = constructEffectiveHamiltonian( sparams, effHamParams);

        [kets,ens] = eig(Heff);
        [~, ind] = sort(diag(ens));
        ens = ens(ind,ind);
        energies(:,ii) = diag(ens);
        
        % Get expectation values
        for jj = 1:nStates
            rhoTemp = kets(:,jj)*kets(:,jj)';
            
            [oExp, vExp, sExp] = getExpectationValues(sparams, rhoTemp);
            % I think since the kets have complex values the expectation
            % values can be complex too even though the complex component
            % is ~= 0.  So just take the real part for now but remember it
            % in case you're debugging.
            switch lower(colorAxisAxis)
                case 'z'
                    orbExp(jj,ii) = real(oExp(3,1));
                    valExp(jj,ii) = real(vExp(3,1));
                    spinExp(jj,ii) = real(sExp(3,1));
                case 'y'
                    orbExp(jj,ii) = real(oExp(2,1));
                    valExp(jj,ii) = real(vExp(2,1));
                    spinExp(jj,ii) = real(sExp(2,1));
                case 'x'
                    orbExp(jj,ii) = real(oExp(1,1));
                    valExp(jj,ii) = real(vExp(1,1));
                    spinExp(jj,ii) = real(sExp(1,1));
                otherwise
            end
        end
    end
 
    figure
    hold on;
    set(gcf,'Color','white');
    set(gca,'Fontsize',14,'TickLabelInterpreter','latex');
    xx = [variedData;variedData]/sparams.ee;
    if (floor(log10(abs(min(min(xx))))) < -3) ||...
            (floor(log10(abs(max(max(xx))))) < -3)
        xx = xx*1E6;
        xlabel('Detuning [$\mu$eV]','Fontsize',18,'Interpreter','latex');
    else
        xlabel('Detuning [eV]','Fontsize',18,'Interpreter','latex');
    end
    energies = energies/sparams.ee;
    if (floor(log10(abs(min(min(energies))))) < -3) ||...
            (floor(log10(abs(max(max(energies))))) < -3)
        energies = energies*1E6;
        ylabel('Energy [$\mu$eV]','Fontsize',18,'Interpreter','latex');
    else
        ylabel('Energy [eV]','Fontsize',18,'Interpreter','latex');
    end
    
    switch lower(colorAxisVariable)
        case 'spin'
            if ~sparams.includeSpin
                error('Spin was not included in the effective Hamiltonian simulation.\nPlease choose a different variable for the color axis.');
            else
                for ii = 1:nStates
                    yy = [energies(ii,:);energies(ii,:)];
                    zz = [spinExp(ii,:);spinExp(ii,:)];
                    surf(xx,yy,zz,'EdgeColor','flat','Linewidth',linewidth);
                end
                hcb = colorbar;
                colormap(jet);
                caxis([-1,1]);
                ylabel(hcb,['Spin $\langle ',colorAxisAxis,'\rangle$'],'Interpreter','latex','Fontsize',18);
            end
        case 'valley'
            if ~sparams.includeValley
                error('Valley was not included in the effective Hamiltonian simulation.\nPlease choose a different variable for the color axis.');
            else
                for ii = 1:nStates
                    yy = [energies(ii,:);energies(ii,:)];
                    zz = [valExp(ii,:);valExp(ii,:)];
                    surf(xx,yy,zz,'EdgeColor','flat','Linewidth',linewidth);
                end
                hcb = colorbar;
                colormap(jet);
                caxis([-1,1]);
                ylabel(hcb,['Valley $\langle ',colorAxisAxis,'\rangle$'],'Interpreter','latex','Fontsize',18);
            end
        case 'orbital'
            if ~sparams.includeOrbital
                error('Orbital was not included in the effective Hamiltonian simulation.\nPlease choose a different variable for the color axis.');
            else
                for ii = 1:nStates
                    yy = [energies(ii,:);energies(ii,:)];
                    zz = [orbExp(ii,:);orbExp(ii,:)];
                    surf(xx,yy,zz,'EdgeColor','flat','Linewidth',linewidth);
                end
                hcb = colorbar;
                colormap(jet);
                caxis([-1,1]);
                ylabel(hcb,['Orbital $\langle ',colorAxisAxis,'\rangle$'],'Interpreter','latex','Fontsize',18);
            end
        otherwise
            plot(xx(1,:),energies,'Linewidth',linewidth,'Color','k');
    end
    % If we triggered the 'otherwise' case in the above switch statement,
    % then there is no hcb so just catch that error.
    try
        set(hcb, 'YAxisLocation','top','Location','north',...
        'TickLabelInterpreter','latex');
    catch
        % Do nothing
    end

    xlim([min(min(xx)),max(max(max(xx)))]);
    view(2);
end

