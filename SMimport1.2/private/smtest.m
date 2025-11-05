% Copyright (C) 2025 Medical Computer Systems ltd. http://mks.ru
% Author: Sergei Simonov (ssergei@mks.ru)

function smtest(wild_mask)
% smtest - try to load with SMimport evey file pointed with wildcard mask
% You have to run eeglab before runing      
% Example of call: smtest('C:\SomeDir\**\*.sm');

dirData = dir(wild_mask);
if isempty(dirData)
    disp('No files found for test');
end
pos = 0;
neg = 0;
for i=1:length(dirData)
    fpath = fullfile(dirData(i).folder, dirData(i).name);
    disp('--------------------')
    disp(fpath);
    try
    ecg = smload(fpath);
    pos = pos + 1;
    catch ME
        fprintf('Error: %s\n', ME.message);
        neg = neg + 1;
        continue;
    end
end

fprintf('total: %d; success: %d; errors: %d\n', neg+pos, pos, neg);
