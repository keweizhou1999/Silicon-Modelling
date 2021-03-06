function saveGIFofEvolution(fig, currSweepValue, currTime, currSaveFolder)
%SAVEGIFOFEVOLUTION Summary of this function goes here
%   Detailed explanation goes here

    [A,map] = rgb2ind(frame2im(getframe(fig)),256);
    fullFnameGIF = [currSaveFolder '/shuttle' num2str(currSweepValue) '.gif'];
    
    if exist(fullFnameGIF,'file')
        imwrite(A,map,fullFnameGIF,...
            'gif','WriteMode','append','DelayTime',0);    
    else
        imwrite(A,map,fullFnameGIF,...
            'gif','LoopCount',Inf,'DelayTime',0);
    end
    
    fullNamePNG = [currSaveFolder '/shuttle' num2str(currTime) '.png'];
    export_fig(fullNamePNG,'-m1','-painters');
%     imwrite(A,map,fullNamePNG);
end

