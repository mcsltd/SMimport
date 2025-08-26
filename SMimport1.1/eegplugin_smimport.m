% eegplugin_smimport() - Plugin to import EEG from an SM file.
%
% Usage:
%   >> eegplugin_smimport(fig, trystrs, catchstrs);
%
% Inputs:
%   fig        - [integer]  EEGLAB figure
%   trystrs    - [struct] "try" strings for menu callbacks.
%   catchstrs  - [struct] "catch" strings for menu callbacks.
%
% Copyright (C) 2025 Medical Computer Systems ltd. http://mks.ru
% Author: Sergei Simonov (ssergei@mks.ru)

function vers = eegplugin_smimport(fig, trystrs, catchstrs)

vers = 'smimport1.0';
if nargin < 3
    error('eegplugin_sm requires 3 arguments');
end

% add folder to path
% -----------------------
if ~exist('pop_readsm','file')
    p = which('eegplugin_sm');
    p = p(1:strfind(p,'eegplugin_sm.m')-1);
    addpath(p);
end

% find import data menu
% ---------------------
menu = findobj(fig, 'tag', 'import data');

% menu callbacks
% --------------

cb_readsm  = [  trystrs.no_check  '[EEG LASTCOM] = pop_readsm;' catchstrs.new_and_hist ];

uimenu( menu, 'label', 'From MCS .SM file', 'callback', cb_readsm, 'separator', 'on');
