function rootPath = bvRootPath()
% Determine path to root of the BCBLViennaSoft directory
%
%        rootPath = bvRootPath;
%
% This function MUST reside in the directory at the base of the
% PRFmodel directory structure 
%
% Copyright GLU 2022
% test
rootPath = which('bvRootPath');

rootPath = fileparts(rootPath);

return
