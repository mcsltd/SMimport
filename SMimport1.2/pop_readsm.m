% POP_READSM - load EEG from an SM file (pop out window if no arguments).
%
% Usage:
%   >> EEG = pop_readsm;             % a window pops up
%   >> EEG = pop_readsm( filename );
%
% Inputs:
%   filename       - path to SM file
% Outputs:
%   EEG            - EEGLAB data structure
%

% Copyright (C) 2025 Medical Computer Systems ltd. http://mks.ru
% Author: Sergei Simonov (ssergei@mks.ru)


function [EEG, com] = pop_readsm(filename)
EEG = [];
com = '';

if nargin < 1
    % ask user
    [filename, filepath] = uigetfile('*.SM;*.sm', ...
        'Choose an SM file -- pop_readesm()');
    drawnow;
    if filename == 0
        return;
    end
    fullpath = [filepath filename];
end
EEG = smload(fullpath);
if nargout > 1
    com = sprintf( 'EEG = pop_readsm(%s);', filename);
end
end