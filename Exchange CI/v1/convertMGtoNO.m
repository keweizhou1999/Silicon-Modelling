function [ vNO ] = convertMGtoNO( gMG )
%CONVERTMGTONO converts meshgrid (MG) format to a vector with natural
%ordering (NO).

    [ny,nx] = size(gMG);
    vNO = reshape(gMG.',[nx*ny,1]);
end

