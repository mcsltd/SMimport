function [globinfo, event_desriptions, siginfo] = parse_block0(block)
% Parsing block0 of SM-file and returns event_desriptions and siginfo
% globinfo - is a struct with .version and .encoding_method elements;
% events_descriptions is cell array, where index is type and
% value is name of event; 
% siginfo is struct array, siginfo's fields consist 
% of <Attributes> and <Metrics> fileds of <Signal> element of BLOCK0
% plus 'uv_per_bit' and 'max_bytes_per_sample' fields calculated 
 
elements = parse_elements(transpose(char(block.data)));

ver = get_elements(elements, 'Version');
globinfo.version = int32(str2double(ver.data));

method = get_elements(elements, 'EncodingMethod');
globinfo.encoding_method = int32(str2double(method.data));

% Load event's information
event_types=[];
try
    event_types = get_elements(elements, 'Controller', 'EventTypes', 'EventType');
catch ME
    if strcmp(ME.identifier,'SMLOADER:ELEMENT_NOT_FOUND')
        % warning('SMLOADER:PARSE','Events descriptions not found');
    else
        rethrow(ME)
    end
end
event_desriptions = {};
for i = 1: length(event_types)
    evt = event_types(i);
    if (isfield(evt,'attributes'))
        etype = NaN;
        edescr = '';
        for j = 1 : length(event_types(i).attributes)
            if strcmp(event_types(i).attributes(j).atrname, 'type')
                etype = str2double(event_types(i).attributes(j).atrval);
            elseif strcmp(event_types(i).attributes(j).atrname, 'description')
                edescr =event_types(i).attributes(j).atrval;
            end
        end
        if ~isnan(etype)
            event_desriptions{etype+1} = strtrim(deblank(edescr));
        end
    end
end

%Load signals informataion
signals = [];
try
    signals = get_elements(elements, 'Controller', 'Record',  'Lead', 'Signals');
catch ME
    if strcmp(ME.identifier,'SMLOADER:ELEMENT_NOT_FOUND')
        warning('SMLOADER:LOAD','Signal descriptions not found');
    else
        rethrow(ME)
    end
end
% For each channel make struct siginfo with fields named like parametres and values
tmp = parse_element_data_deep(signals);
signals = tmp.data;
siginfo = cell(length(signals), 1);
for i = 1 : length(signals)
    for j =  1 : length(signals(i).data)
        for k =  1 : length(signals(i).data(j).data)
            siginfo{i}.(lower(signals(i).data(j).data(k).name)) = signals(i).data(j).data(k).data;
        end
    end
    siginfo{i} = postprocess_sig(siginfo{i});
end

end


% =================== Helper functions ================================= %

function sig = postprocess_sig(sig) 
        bps = int32(sig.bitspersample);
        valuebits = int32(sig.valuebits);
        sig.uv_per_bit = 1000000 * sig.resolution;
        if isempty(valuebits)
            sig.max_bytes_per_sample = idivide(bps,8,'ceil');
        else
            sig.max_bytes_per_sample = idivide(valuebits, 8, 'ceil');
        end
        if sig.max_bytes_per_sample < 2 || sig.max_bytes_per_sample > 4 
          error('SMLOADER:LOAD', 'Channel %d configuration (BPS = %d, ValueBits =%d) unsupported', ...
          sig.name, sig.bitspersample, sig.valuebits)
        end   
end


function e = parse_element_data_deep(e)
if isempty(e.data)
    return;
end
data = parse_elements(e.data);
if ~isempty(data)
    e.data = data;
    for i = 1 : length(e.data)
        e.data(i) = parse_element_data_deep(e.data(i));
    end
    return
else
    % not an element
    if e.data(end) == char(0)
        % строка
        if length(e.data)>1
            e.data = char(e.data(1:end-1));
        else
            e.data = '';
        end
    elseif regexpi(e.data,'^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$')
        % uuid - оставляем строкой
    else
        % uuid - число
        val =  str2double(e.data);
        if ~isnan(val)
            e.data = val;
        else
            warning('SMLOADER:PARSE', 'unexpected data type (%s) for element %s', e.data, e.name);
        end
    end
end
end
