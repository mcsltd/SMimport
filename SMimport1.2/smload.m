function r = smload(file_path)
% smload(file_path) - Import SM-file and return EEG struct

% Copyright (C) 2025 Medical Computer Systems ltd. http://mks.ru
% Author: Sergei Simonov (ssergei@mks.ru)

originalWarningState = warning('query', 'backtrace');
warning('off', 'backtrace');
cleanupObj = onCleanup(@() warning(originalWarningState));

%checking eeglab functions
if ~exist('eeg_emptyset','file')
    % need to start eeglab to add paths to it's functions
    eeglab('nogui');
end

%Сhecking mex files
mex_block_ok = check_mex("smcrc32","x=smcrc32([int8(32)]);");
mex_frame_ok = check_mex("smdecode","x=smdecode([int8(32)],1,2,0.001,0);");

block_iter = smBlockIterator(file_path, mex_block_ok);
[block_iter, b0] = block_iter.next();
if b0.type ~=0
    error('SMLOADER:PARSE','Block0 is missing');
end

[globinfo, event_desriptions,  siginfo] = parse_block0(b0);
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
    warning('SMLOADER:MEX', 'Boosting mex-files not found - processing could be slow. Run smbuildmex to fix it.');
end

% Preview. Calculate min and max sample number for each channel
% And save frames descriptions for each channel
for i = 1: length(siginfo)
    siginfo{i}.('frames') = {};
    siginfo{i}.('min_tick') = [];
    siginfo{i}.('max_tick') = [];
end
presize = 16000; % can't predict the number of frames
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


% Remove all channels without data
with_data_signals = cellfun(@(x) ~isempty(x.min_tick) && ~isempty(x.max_tick), siginfo);
si = siginfo(with_data_signals);
if (isempty(si))
    error('SMLOADER:LOAD', 'Record doesn''t contains any signal''s data')
end
for i = 1: length(with_data_signals)
    if with_data_signals(i) == 0
        warning('SMLOADER:LOAD', 'Channel %s doesn''t contains signal''s data and won''t be imported', makeChanLabel(siginfo{i}));
    end
end
[sm2eeg, eeg2sm]  = makeMaps(with_data_signals);
clear siginfo;




all_frames = all_frames(1:frame_counter);
all_events = all_events(1:event_counter);
gmin_tick = min(extractfiled(si,'min_tick')); 
gmax_tick = max(extractfiled(si,'max_tick')); 
freq = si{1}.freq;
if ~all(extractfiled(si,'freq') == freq) ~= 0
    error('SMLOADER:LOAD', 'Variative channel''s sample rates are not supported')
end


nbchan = length(si);
pnts = gmax_tick - gmin_tick + 1;
EEG = eeg_emptyset;
EEG.setname = file_path;
EEG.comments = ['Information will be placed here later' ];
EEG.pnts = double(pnts);
EEG.nbchan = nbchan;
EEG.trials = 1;
EEG.srate = double(freq);
EEG.xmin = double(gmin_tick/freq);
EEG.xmax = double(gmax_tick/freq);
EEG.ref = 'common';
EEG.data = zeros(nbchan, pnts, 1, 'single');
%EEG.times =  [EEG.xmin: 1000.0/siginfo{1}.freq:EEG.xmax];

% labels for channels
for i = 1 : nbchan
    EEG.chanlocs(i).labels = char(makeChanLabel(si{i}, i));
    EEG.chanlocs(i).channum = eeg2sm(i);
    if isfield(si{i}, 'type') && ~isempty(si{i}.type)
        EEG.chanlocs(i).type = si{i}.type;
    end
end

% Placing EEG.data
offset = -gmin_tick + 1;

for i = 1 : length(all_frames)
    frame = all_frames{i};
    block = block_iter.extract_block(frame.block_id);
    frame_iter = frame_iter.reset(block);
    xxx = frame_iter.decode(frame);
    index = sm2eeg(frame.channel);
    EEG.data(index, offset+frame.start_tick:offset+frame.start_tick+frame.size-1) = xxx;
end


% Filing gaps at the start and at the end
for i = 1: length(si)
    if si{i}.min_tick > gmin_tick
       EEG.data(i, 1 : si{i}.min_tick + offset - 1) = EEG.data(i, si{i}.min_tick + offset);
       warning('SMLOADER:gap', ...
            'Channel %s starting gap of %.2f seconds filled with ''first known'' value', ...
             EEG.chanlocs(sm2eeg(frame.channel)).labels, ...
             double(si{i}.min_tick - gmin_tick)/freq);

        
    end
    if si{i}.max_tick  < gmax_tick
        EEG.data(i, si{i}.max_tick + offset : end) = EEG.data(i, si{i}.max_tick + offset - 1);
        warning('SMLOADER:gap', ...
            'Channel %s ending gap of %.2f seconds filled with ''last known'' value', ...
            EEG.chanlocs(sm2eeg(frame.channel)).labels, ...
            double(gmax_tick - si{i}.max_tick)/freq);
    end
end

% check signal gaps and fill it with last known value
% expecting that frames go in ordered way in file
%[~, sorted_indexes] = sort(all_frames.start_tick);
%all_frames = all_frames(sorted_indexes);
for i = 1 : length(all_frames) - 1
    a = all_frames{i}.start_tick + all_frames{i}.size + offset;
    b = all_frames{i+1}.start_tick + offset;
    if b>a
        index = sm2eeg(frame.channel);
        warning('SMLOADER:gap', ...
            'Channel %s gap (%.2f, %.2f) filled with ''last known'' value', ...
            EEG.chanlocs(index).labels, double(a)/freq, double(b)/freq);
        EEG.data(index, a : b-1) = zeros(1,b-a,"single") + EEG.data(index,a-1);
    end
end


% Placing EEG.event
for i = 1 : event_counter
    urev.type = event_desriptions{all_events{i}.type+1};
    ch = all_events{i}.channel;
    if  ch > 0 && ch <= length(sm2eeg) && sm2eeg(ch)>ch
       urev.channel =  EEG.chanlocs(sm2eeg(ch)).labels;
    else
        urev.channel =  'None';
    end
    
    urev.latency = double(all_events{i}.start_tick + offset);
    urev.creation_time = string(datetime(all_events{i}.crtime, ...
        'ConvertFrom','posixtime','Format','dd-MMM-uuuu HH:mm:ss'));
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


function res = getFieldSafe(struct, fieldName, def)
  if isfield(struct, fieldName) && ~isempty(struct.(fieldName))
      res = struct.(fieldName);
  else
      res = def;
  end
end

function label = makeChanLabel(sinf, def)
    name = getFieldSafe(sinf, 'name',"");
    source = getFieldSafe(sinf, 'source',"");
    if name == "" && source == ""
        label = string(def);
    elseif name == ""
       label = source; 
    elseif source == ""
            label = name;
    else
        label = name+"/"+source;
    end
end

% bit array массив, в котором 0 - удаляемая строка, 1 - сохраняемая
% Из исходного массива удаюлются строки
% Fmap[индекс исходного] =  индексу исходного
% Bmap[индекс нового] = индексу исходного
function [Fmap, Bmap] = makeMaps(flags)
    Fmap = cumsum(flags);
    Bmap = zeros(Fmap(end), 1);
    index = 1;
    for i = 1: length(flags)
        if flags(i) ~= 0
            Bmap(index) = i;  
            index = index+1; 
        end
    end
end




