% Load all the parameters for the simulation
% dbstop if error;
clear sparams xx vv;
shuttleParameterFile;

fprintf(1,'Loading potentials...\n');
[sparams,xx,zz] = loadPotentials(sparams);
% [xx,vv] = loadPotentialsFromFigure(sparams);
%%
sparams.nxGrid = length(xx);
sparams.nzGrid = length(zz);
sparams.dx = xx(2) - xx(1);
sparams.dz = zz(2) - zz(1);
sparams.dp = 2*pi*sparams.hbar/(sparams.dx*sparams.nxGrid);
pp = ((-sparams.nxGrid/2):1:(sparams.nxGrid/2 - 1))*sparams.dp;

% Find which index corresponds to where the 2DEG should be
[~,sparams.twoDEGindZ] = min(abs(zz - (-0.5*1E-9)));
for ii = 1:length(sparams.potentials)
    sparams.potentials(ii).pot2DEG = sparams.potentials(ii).pot2D(sparams.twoDEGindZ,:);
end

% Now we want to make the potential interpolant object (both 2D and 2DEG)
sparams = makePotentialsInterpolants(sparams,xx,zz);
%%
% Check that the potentials were loaded correctly and that the interpolants
% were correctly assembled
debugHere = 1;
if debugHere && sparams.verbose
    test = 0.98:0.001:1.02;

    fig = figure;
    for ii = 1:length(test)
        clf;
        testPot = sparams.P2DEGInterpolant({1.0,test(ii),0.7,xx});
        plot(xx,squeeze(testPot)/sparams.ee);
        pause(0.2);
    end
    delete(fig);
    
    [XX,ZZ] = meshgrid(xx,zz);
    fig = figure;
    testPot = sparams.P2DInterpolant({1.0,0.7,0.7,zz,xx});
    s = surf(XX,ZZ,squeeze(testPot));
    set(s,'edgecolor','none');
    view(2);
    pause(1);
    delete(fig);
end

%%
% fig = figure;
% testPot = squeeze(sparams.P2DEGInterpolant({1.0,0.99,0.7,xx}));
% plot(xx,testPot/sparams.ee);

% Get our desired votlage pulse.
sparams = getVoltagePulse(sparams,xx);

debugHere = 1;
if debugHere
    fig = figure;
    hold on;
    for ii = 1:sparams.numOfGates
        plot(sparams.voltagePulse(ii,:),'Linewidth',2);
    end
%     pause(5);
%     delete(fig);
end


fprintf(1,'Getting initial wavefunction...\n');
% Solve the 1D SE for the initial potential well to get what our ground
% state should look like
vvInterp = squeeze(sparams.P2DEGInterpolant([num2cell(sparams.voltagePulse(:,1)'),...
        mat2cell(xx,1,length(xx))]));
    
[sparams.rho0, ~] = solve1DSingleElectronSE(sparams,1,xx,vvInterp); 

% Check that the intial state makes sense
debugHere = 1;
if debugHere
    fig = figure;
    hold on;
    plot(xx,vvInterp/sparams.ee);
    plot(xx,abs(sparams.rho0).^2/2000000000 + min(vvInterp/sparams.ee));
    title('Initial conditions');
    pause(5);
    delete(fig);
end
%%
% Using ref https://arxiv.org/pdf/1306.3247.pdf we now find the time
% evolution operator U(t + dT,t) to evolve our initial wavefunction to the
% next wavefunction.  That newly found wavefunction will act as our initial
% state for the next time frame.  This method uses the split ooperator
% approach
    
% Make the KE operator since it is the same every time it is applied
K = exp(-1i*sparams.dt/2*(pp.^2)/(2*sparams.me*sparams.hbar));
K2 = K.*K;

% Make the fidelity array
maxTime = max(sparams.totalTime);
maxLength = length(0:sparams.dt:maxTime);
sparams.fidelity = zeros(length(sparams.totalTime),floor(maxLength/sparams.updateFidelity));
sparams.starkShift = zeros(length(sparams.totalTime),sparams.nStarkShiftFrames);

sparams.avgEzGround = zeros(length(sparams.totalTime),sparams.nStarkShiftFrames);
sparams.avgEz = zeros(length(sparams.totalTime),sparams.nStarkShiftFrames);
sparams.vShiftGround = zeros(length(sparams.totalTime),sparams.nStarkShiftFrames);
sparams.vShift = zeros(length(sparams.totalTime),sparams.nStarkShiftFrames);

for jj = 1:length(sparams.totalTime)
    tic;
    
    % Now, we want to associate each potential simulation we have with a time
    % value (i.e. when in the simulation should that potential appear)
    tPots = linspace(0,sparams.totalTime(jj),101);
    
    % Now we need to make the individual pulses interpolants
    sparams.vPulseG1Interpolant = griddedInterpolant({tPots},sparams.voltagePulse(1,:));
    sparams.vPulseG2Interpolant = griddedInterpolant({tPots},sparams.voltagePulse(2,:));
    sparams.vPulseG3Interpolant = griddedInterpolant({tPots},sparams.voltagePulse(3,:));
    
    % Get number of time steps
    tTime = 0:sparams.dt:sparams.totalTime(jj);
    nTime = length(tTime);

    % Get time indices to save figures
    saveFigureIndices = round(linspace(1,nTime,sparams.nFigureFrames));
    % Get time indices and corresponding time values to calculate and save starkShift
    sparams.starkShiftIndices(jj,:) = round(linspace(1,nTime,sparams.nStarkShiftFrames));
    sparams.tStarkShift(jj,:) = tTime(sparams.starkShiftIndices(jj,:));
    
    fprintf(1,'Running shuttling simulation for %E (%d/%d)...\n',sparams.totalTime(jj),jj,length(sparams.totalTime));

    % Make the waitbar to show run time
    h = waitbar(0,sprintf('Current Time Index: %d/%d',0,nTime),...
        'Name',sprintf('Performing shuttling simulation for %E...',sparams.totalTime(jj)),...
        'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    movegui(h,'northwest');

    currPsi = sparams.rho0';
    shtlEvolutionFig = figure;
    
    nn = 1; % Used to index fidelity array
    mm = 1; % Used to index gif creation
    ll = 0; % Used to know where in time domain to interpolate our potentials
    kk = 0; % Used to index which interpolated potential we are on
    yy = 0; % Used for stark shift indexing

    % Convert from position to momentum space
    currPsip = fftshift(fft(fftshift(currPsi)));
    % Apply the KE operator for dt/2 
    currPsip = K.*currPsip;
    
    for ii = 1:nTime
        kk = kk + 1;
        
        % Check for cancel button click
        if getappdata(h,'canceling')
            flag = 1;
            break;
        end

        % Update waitbar every N frames
        if mod(ii,sparams.updateWaitbar) == 0
            waitbar(ii/nTime, h, sprintf('Current Time Index: %d/%d',ii,nTime));
        end

        % Get updated set of interpolated potentials if needed
        if mod(ii,sparams.updateInterpPot) == 0 || ii == 1
            if strcmp(sparams.interpType,'linear')
                kk = 1; % Reset counter
                startInterpInd = ll*sparams.updateInterpPot;
                if ii == 1
                    startInterpInd = 1;
                end
                ll = ll + 1;
                endInterpInd = ll*sparams.updateInterpPot - 1;
                if endInterpInd > nTime
                    endInterpInd = nTime;
                end
                
                % Get the voltage gate values for the current time index
                g1 = sparams.vPulseG1Interpolant({tTime(startInterpInd:endInterpInd)});
                g2 = sparams.vPulseG2Interpolant({tTime(startInterpInd:endInterpInd)});
                g3 = sparams.vPulseG3Interpolant({tTime(startInterpInd:endInterpInd)}); 
            end
        end
        
        currPotential = squeeze(sparams.P2DEGInterpolant({g1(kk),g2(kk),g3(kk),xx}))';
        
        % Need to put this somewhere else eventually...
        if ii == 1
            sparams.figWFMin = min(currPotential);
        end
        
%         V = exp(-1i*sparams.dt*vvInterp(kk,:)/sparams.hbar);
        V = exp(-1i*sparams.dt*currPotential/sparams.hbar);

        % Convert from momentum to position space
        currPsix = fftshift(ifft(fftshift(currPsip)));
        % Apply the PE operator for dt
        currPsix = V.*currPsix;
        % Convert from position to momentum space
        currPsip = fftshift(fft(fftshift(currPsix)));
        if ii ~= nTime
            % Apply the KE operator for dt
            currPsip = K2.*currPsip;
        else
            % Apply the KE operator for dt/2
            currPsip = K.*currPsip;
            % Convert from momentum to position space
            currPsi = fftshift(ifft(fftshift(currPsip)));
        end
       

        % Calculate Stark shift
        if any(sparams.starkShiftIndices(jj,:) == ii) && sparams.calculateStarkShift
            yy = yy + 1;

            % Convert Psi to position space
            currPsiTemp = fftshift(ifft(fftshift(currPsip)));
            
            % Get the current interpolated 2D potential
            curr2DPot = squeeze(sparams.P2DInterpolant({g1(kk),g2(kk),g3(kk),zz,xx}));
            sparams.stark2DPots(yy,:) = curr2DPot(sparams.twoDEGindZ,:);
                        
            % Find the electric field
            [currEx,currEz] = gradient(curr2DPot/sparams.ee,sparams.dx,sparams.dz);
            currEz = -currEz;

            % Find ground state of current potential
            currGroundState = solve1DSingleElectronSE(sparams,1,xx,curr2DPot(sparams.twoDEGindZ,:));

            % Find average Ez seen by the ground state and current
            % simulated wavefunction
            sparams.avgEzGround(jj,yy) = getInnerProduct(xx,currGroundState.',currEz(sparams.twoDEGindZ,:).*currGroundState.');
            sparams.avgEz(jj,yy) = getInnerProduct(xx,currPsiTemp,currEz(sparams.twoDEGindZ,:).*currPsiTemp);
            % Find shift in resonance frequency seen by the ground state
            % and the current simulated wavefunction
            sparams.vShiftGround(jj,yy) = sparams.n2*sparams.v0*(abs(sparams.avgEzGround(jj,yy))^2) + sparams.v0;
            sparams.vShift(jj,yy) = sparams.n2*sparams.v0*(abs(sparams.avgEz(jj,yy))^2) + sparams.v0;
        end
        
        % Update figure every N frames and save to gif
        if mod(ii,sparams.updateFigure) == 0
            [currRho0, ~] = solve1DSingleElectronSE(sparams,1,xx,currPotential);
            
            updateFigure(sparams,shtlEvolutionFig,fftshift(ifft(fftshift(currPsip))),...
                currRho0,xx,currPotential,jj);
        end

        % Update figure and save to gif according to figure frames
        % parameter
        if any(saveFigureIndices == ii)
%             fprintf(1,'Curr Gate Values %0.6f %0.6f %0.6f\n',g1(kk),g2(kk),g3(kk));
            [currRho0, ~] = solve1DSingleElectronSE(sparams,1,xx,currPotential);
            
            updateFigure(sparams,shtlEvolutionFig,fftshift(ifft(fftshift(currPsip))),...
                currRho0,xx,currPotential,jj);
                        
            [A,map] = rgb2ind(frame2im(getframe(shtlEvolutionFig)),256);
            if mm == 1
                imwrite(A,map,['shuttle' num2str(sparams.totalTime(jj)) '.gif'],'gif','LoopCount',Inf,'DelayTime',0);
            else
                imwrite(A,map,['shuttle' num2str(sparams.totalTime(jj)) '.gif'],'gif','WriteMode','append','DelayTime',0);
            end
            mm = mm + 1;
        end
        
        % Calculate fidelity with current ground state every N frames
        if mod(ii,sparams.updateFidelity) == 0
            currPsiTemp = fftshift(ifft(fftshift(currPsip)));
            % Need to get the ground state of the current potential
%             [currRho0, ~] = solve1DSingleElectronSE(sparams,1,xx,vvInterp(kk,:));
            [currRho0, ~] = solve1DSingleElectronSE(sparams,1,xx,currPotential);
            sparams.fidelity(jj,nn) = abs(getInnerProduct(xx,currRho0.',currPsiTemp))^2;
            nn = nn + 1;
        end
    end
    
    % Close simullation figure
    close(shtlEvolutionFig);
    % Close waitbar
    delete(h);
    % Delete currIm
    clearvars currIm
    toc;
end


%% Post simulation Analysis
% fids = sparams.fidelity;
fids = sparams.fidelity;
fids(fids==0) = NaN;
[rows,cols] = size(fids);
highTime = max(sparams.totalTime);
fidTimeIndices = sparams.updateFidelity*sparams.dt:sparams.updateFidelity*sparams.dt:highTime;
[TIndex,TTime] = meshgrid(fidTimeIndices,[0,sparams.totalTime,2*max(sparams.totalTime)]);
fidelTemp = zeros(rows+2,cols);
fidelTemp(2:(rows+1),:) = fids;

figure;
s = surf(TIndex,TTime,fidelTemp);
set(s,'edgecolor','none');
set(gca,'XScale','log');
set(gca,'YScale','log');
xlabel('Time step $t_j$ [s]','interpreter','latex','fontsize',15);
ylabel('Total Shuttling Simulated Time [s]','interpreter','latex','fontsize',15);
xlim([min(min(TIndex)),max(max(TIndex))]);
ylim([0,2*max(sparams.totalTime)]);
title('Fidelity: $$|\langle\Psi_0(t_j)|\Psi_{\rm sim}(t_j)\rangle|^2$$','interpreter','latex','fontsize',15);
view(2);
colormap(jet);
colorbar;

if sparams.calculateStarkShift
    for ii = 1:length(sparams.totalTime)
        if mod(ii-1,6) == 0
            fig = figure;
            pos = get(fig,'position');
            set(fig,'position',[pos(1:2)/4 pos(3)*2.0 pos(4)*1.25]);
        end

        subplot(2,3,mod(ii-1,6)+1);
        hold on;
        plot(sparams.tStarkShift(ii,:),(sparams.vShift(ii,:)-sparams.vShift(ii,1))*1E-6);
        plot(sparams.tStarkShift(ii,:),(sparams.vShiftGround(ii,:)-sparams.vShift(ii,1))*1E-6);
        xlabel('Time index [s]','interpreter','latex','fontsize',10);
        ylabel('$\nu - \nu_0$ [MHz]','interpreter','latex','fontsize',10);
        title(['Shuttling Simulation ' num2str(sparams.totalTime(ii)) '[s]'],'interpreter','latex','fontsize',10);
        drawnow;
    end
end