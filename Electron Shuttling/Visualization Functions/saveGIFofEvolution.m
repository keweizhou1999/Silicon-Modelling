function saveGIFofEvolution(sparams, fig, currSweepValue, currTime)
%SAVEGIFOFEVOLUTION Summary of this function goes here
%   Detailed explanation goes here

    [A,map] = rgb2ind(frame2im(getframe(fig)),256);
    fullFnameGIF = [sparams.saveDir sparams.saveFolder num2str(currSweepValue)...
        '/' 'shuttle' num2str(currSweepValue) '.gif'];
    
    if exist(fullFnameGIF,'file')
        imwrite(A,map,fullFnameGIF,...
            'gif','WriteMode','append','DelayTime',0);    
    else
        imwrite(A,map,fullFnameGIF,...
            'gif','LoopCount',Inf,'DelayTime',0);
    end
    
    fullNameJPEG = [sparams.saveDir sparams.saveFolder num2str(currSweepValue)...
        '/' 'shuttle' num2str(currTime) '.jpeg'];
    imwrite(A,map,fullNameJPEG);
end

