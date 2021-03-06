function [ sparams ] = solveShiftToNonShiftedCoeffs( sparams, X, Y )
%SOLVESHIFTTONONSHIFTEDCOEFFS Summary of this function goes here
%   Detailed explanation goes here    
    sparams.bcoeffs = zeros(sparams.nSingleOrbitals,sparams.nNonShiftedHOs);
    
    h = waitbar(0,'1','Name','Unfolding Shifted HOs...',...
        'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    
    kk = 0;
    flag = 0;
    for jj = 1:sparams.nNonShiftedHOs
        nonShiftedMG = sparams.nonShiftedHOs(jj).wavefunctionMG;
        for ii = 1:sparams.nSingleOrbitals
            %Check for cancel button click
            if getappdata(h,'canceling')
                flag = 1;
                break;
            end
            shiftedMG = sparams.sLocalHOs(ii).wavefunctionMG;
            
            % B matrix with B_ij = <alpha_j|r_i>
            sparams.bcoeffs(ii,jj) = getInnerProduct(nonShiftedMG,shiftedMG,X,Y);
            
            kk = kk + 1;
            % Update waitbar
            if mod(kk,3) == 0
                waitbar(kk/(sparams.nSingleOrbitals*sparams.nNonShiftedHOs), h,...
                    sprintf('Shifted Index:%04d/%d  Non-shifted Index:%04d/%d',...
                    jj,sparams.nNonShiftedHOs,ii,sparams.nSingleOrbitals));
            end
        end
        if flag == 1
            break;
        end
    end
    
    % Normalize each row 
    for ii = 1:sparams.nSingleOrbitals
        sparams.bcoeffs(ii,:) = sparams.bcoeffs(ii,:)/norm(sparams.bcoeffs(ii,:));
    end
    
    % Close waitbar
    delete(h);
end

