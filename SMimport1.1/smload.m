function r = smload(file_path)
% smload(file_path) - Imporintg SM-file and returns EEG struct

% Copyright (C) 2025 Medical Computer Systems ltd. http://mks.ru
% Author: Sergei Simonov (ssergei@mks.ru)


%checking eeglab functions
if ~exist('eeg_emptyset','file')
    % need to start eeglab to add paths to it's functions
    eeglab('nogui');
end

%Ñhecking mex files
mex_block_ok = check_mex("smcrc32","x=smcrc32([int8(32)]);");
mex_frame_ok = check_mex("smdecode","x=smdecode([int8(32)],1,2,0.001,0);");

block_iter = smBlockIterator(file_path, mex_block_ok);
[block_iter, b0] = block_iter.next();
if b0.type ~=0
    error('SMLOADER:PARSE','Block0 is missing');
end

[globinfo, event_desriptions, siginfo] = parse_block0(b0);
if globinfo.version ~= 1
    error('SMLOADER:PARSE', 'SM-file version (%d) is not supported', globinfo.version)
end

if  globinfo.encoding_method ~= 0  && globinfo.encoding_method ~= 1
    error('SMLOADER:PARSE', 'Encoding method (%s) is not supported', globinfo.encoding_method)
end

if isempty(siginfo)
    error('SMLOADER:PARSE','File doesn''t contains any signal information');
end

if mex_block_ok == false || mex_frame_ok == false
    warning('SMLOADER:MEX', ['Boosting mex-files not found - processing could be slow. Run smbuildmex to fix it.']);
end

% Preview. Calculate min and max sample number for each channel
% And save frames descriptions for each channel
for i = 1: length(siginfo)
    siginfo{i}.('frames') = {};
    siginfo{i}.('min_tick') = [];
    siginfo{i}.('max_tick') = [];
end

presize = 16000;
% we really can't predict the number of frames
% if isfield(siginfo{1},durationticks)
%     if ~isempty(siginfo{1}.durationticks)
%         presize = siginfo{1}.durationticks/256;
%     end
% end
all_frames = cell(1, presize);
all_events = cell(1, presize);
frame_counter = uint64(0);
event_counter = uint64(0);

frame_iter = smFrameIterator(siginfo, mex_frame_ok, globinfo.encoding_method);
while true
    [block_iter, bx] = block_iter.next();
    if isempty(bx); break; end
    if bx.type == 1
        frame_iter=frame_iter.reset(bx);
        while true
            [frame_iter, frame] = frame_iter.next();
            if isempty(frame); break; end
            if isempty(siginfo{frame.channel}.min_tick)
                siginfo{frame.channel}.min_tick = frame.start_tick;
                siginfo{frame.channel}.max_tick = frame.start_tick + frame.size - 1;
            else
                if  siginfo{frame.channel}.max_tick >= frame.start_tick
                    error("SMLOAD:PARSE","unsorted data frames is not unsupprted %d >= %d", siginfo{frame.channel}.max_tick, frame.start_tick)
                end
                siginfo{frame.channel}.max_tick = max([siginfo{frame.channel}.max_tick, frame.start_tick + frame.size-1]);
                siginfo{frame.channel}.min_tick = min([siginfo{frame.channel}.min_tick, frame.start_tick]);
            end
            siginfo{frame.channel}.frames{end+1} = [frame.block_id, frame.id, frame.size, frame.start_tick];
            frame_counter = frame_counter + 1;
            all_frames{frame_counter} = frame;
        end
    elseif bx.type == 2
        ev_iter = smEventIterator(siginfo, bx);
        while true
            [ev_iter,ev] = ev_iter.next();
            if isempty(ev); break; end
            event_counter = event_counter + 1;
            all_events{event_counter} =  ev;
        end
    end
end % while

for i = 1: length(siginfo)
    if isempty( siginfo{i}.('min_tick')) || isempty(siginfo{i}.('max_tick'))
        error('SMLOADER:LOAD', 'Records with empty channels (witout any data) aren''t supported')
    end
end

all_frames = all_frames(1:frame_counter);
all_events = all_events(1:event_counter);
gmin_tick = siginfo{1}.min_tick;
gmax_tick = siginfo{1}.max_tick;
freq = siginfo{1}.freq;


if ~all(extractfiled(siginfo,'max_tick') == gmax_tick)
    error('SMLOADER:LOAD', 'Records with variative channel''s stop time i aren''t supported')
end
if ~all(extractfiled(siginfo,'min_tick') == gmin_tick) ~= 0
    error('SMLOADER:LOAD', 'Records with variative channel''s start time aren''t supported')
end

if ~all(extractfiled(siginfo,'freq') == freq) ~= 0
    error('SMLOADER:LOAD', 'Records with variative channel''s sample rates are not supported')
end


nbchan = length(siginfo);
pnts = gmax_tick - gmin_tick + 1;
EEG = eeg_emptyset;
EEG.setname = file_path;
EEG.comments = [ 'Information will be placed here later' ];
EEG.pnts = double(pnts);
EEG.nbchan = nbchan;
EEG.trials = 1;
EEG.srate = double(freq);
EEG.xmin = double(gmin_tick/freq);
EEG.xmax = double(gmax_tick/freq);
EEG.ref = 'common';
EEG.data = zeros(nbchan, pnts, 1, 'single');
%EEG.times =  [EEG.xmin: 1000.0/siginfo{1}.freq:EEG.xmax];
for i = 1 : nbchan
    EEG.chanlocs(i).labels = siginfo{i}.name;
end

% Placing EEG.data
offset = -gmin_tick + 1;

for i = 1 : length(all_frames)
    frame = all_frames{i};
    block = block_iter.extract_block(frame.block_id);
    frame_iter = frame_iter.reset(block);
    xxx = frame_iter.decode(frame);
    EEG.data(frame.channel, offset+frame.start_tick:offset+frame.start_tick+frame.size-1) = xxx;
end

% check signal gaps and fill it with last known value
% expecting that frames go in odered way in file
%[~, sorted_indexes] = sort(all_frames.start_tick);
%all_frames = all_frames(sorted_indexes);
for i = 1 : length(all_frames) - 1
    a = all_frames{i}.start_tick + all_frames{i}.size + offset;
    b = all_frames{i+1}.start_tick + offset;
    if b>a
        warning('SMLOADER:gap', 'filling gap of size %d with ''last known element'' startegy', b-a);
        EEG.data(frame.channel, a : b-1) = zeros(1,b-a,"single") + EEG.data(a-1);
    end
end

% Placing EEG.event
for i = 1 : event_counter
    urev.type = event_desriptions{all_events{i}.type+1};
    urev.channel = siginfo{all_events{i}.channel}.name;
    urev.latency = all_events{i}.start_tick + offset;
    urev.creation_time = string(datetime(all_events{i}.crtime, 'ConvertFrom','posixtime','Format','dd-MMM-uuuu HH:mm:ss'));
    urev.payload = all_events{i}.body;
    ev = urev;
    ev.urevent = i;
    if i == 1
        EEG.urevent = urev;
        EEG.event = ev;
    else
        EEG.urevent(end+1) = urev;
        EEG.event(end+1) = ev;
    end
end
r = EEG;
end

% =================== Helper functions ================================= %

function res = extractfiled(cs, name)
res = zeros(1, length(cs), class(cs{1}.(name)));
for i = 1 :length(cs)
    res(i) = cs{i}.(name);
end
end