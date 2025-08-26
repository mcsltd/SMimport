% Copyright (C) 2025 Medical Computer Systems ltd. http://mks.ru
% Author: Sergei Simonov (ssergei@mks.ru)

classdef smEventIterator
    % EventIterator  Extractor of frames with samples from 
    % SM-file block in iterator style
    %
    % Event is sruct with fields
    %   id - unique id of event, equals offset of start position in block
    %   block_id - id of block, where the frame is located
    %   type - type of event
    %   channel - number of channel
    %   crtime - creation time of event
    %   mfreq - freq of event in Hz
    %   start_tick - starting tick number of first sample in
    %   raw_size - lenght in block2
    %   body - (optional) array of decoded data of single
    %
    % For iteration call next(), which returns a block When next() returns
    % empty array, it means EOF reached. It's possible to extract block
    % directly by it's id later with extract_block() funciton

    properties (Access = protected)
        EVENT_HEADER_SIZE = 26;
        block
        pos
        size
        siginfo
    end
    methods
        function obj = smEventIterator(siginfo, block)
            if (length(siginfo)>255)
                obj.EVENT_HEADER_SIZE =  obj.EVENT_HEADER_SIZE+1;
            end
            obj.siginfo = siginfo;
            obj.block = block;
            obj.pos = 1;
            obj.size = length(block.data);
        end

        function [obj, ev] = next(obj)
            if obj.pos + obj.EVENT_HEADER_SIZE - 1 > obj.size
                ev = [];
                return;
            end
            ev.block_id = obj.block.id;
            ev.id = obj.pos-1;
            i = obj.pos;
            ev.type = typecast(obj.block.data(i:i),'uint8');
            i = i + 1;
            ev.crtime = typecast(obj.block.data(i:i+7),'int64');
            i = i + 8;
            ev.mfreq = typecast(obj.block.data(i:i+3),'int32');
            i = i + 4;
            ev.start_tick = typecast(obj.block.data(i:i+7),'int64');
            i = i + 8;
            if (length(obj.siginfo)>255)
                ev.channel = double(typecast(obj.block.data(i:i+1),'uint16')) + 1;
                i = i + 2;
            else
                ev.channel = double(typecast(obj.block.data(i:i),'uint8')) + 1;
                i = i + 1;
            end
            body_symbols = typecast(obj.block.data(i:i+3),'uint32');
            i = i + 4;
            ev_end_pos = i + 2*body_symbols - 1;
            if ev_end_pos > obj.size
                error('SMLOADER:DECODE_EVENT', 'Event body is out of range.');
            end
            if (body_symbols > 0)
                ev.body = char(typecast(obj.block.data(i: ev_end_pos),'uint16'));
            else
                ev.body = '';
            end
            obj.pos = ev_end_pos + 1;
        end
    end
end