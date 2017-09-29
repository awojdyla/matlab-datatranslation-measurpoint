
% Adds the src dir to the MATLAB's path
% @return void
function [] = addSrc()

    [cDirThis, ~, ~] = fileparts(mfilename('fullpath'));
    cDirSrc = fullfile(cDirThis, '..', 'src');
    addpath(genpath(cDirSrc));

end


