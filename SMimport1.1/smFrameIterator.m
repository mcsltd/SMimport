% smFrameIterator - Internal class of SMimport for decoding SM-file records.
% Copyright (C) 2025 Medical Computer Systems ltd. http://mks.ru
% Author: Sergei Simonov (ssergei@mks.ru)

classdef smFrameIterator
    % SignalFramelterator
    % Extractor of frames with samples from
    % SM-file block in iterator style
    %
    % Frame is sruct with fields
    %   id - unique id of frame, equals offset of start position in block
    %   block_id - id of block, where the frame is located
    %   channel - number of channel
    %   start_tick - starting tick number of first sample in frame
    %   size - number of samples in frame
    %   bytes data - (optional) array of decoded data of single
    %
    % For iteration call next(), which returns a Frame. When next() returns
    % empty array, it means end of block reached. It's possible to extract
    % frame directly by it's id later with decode() funciton

    properties (Constant = true, Hidden = true)
        FRAME_HEADER_SIZE = 18;
        INT8_MAX = int8(hex2dec('7f'));
        INT16_MAX = int16(hex2dec('7fff'));
    end
    properties (Access = protected)
        block
        pos
        size
        siginfo
        encoding_method
        mex_support = false;
    end
    methods
        function obj = smFrameIterator(siginfo, mex_support, encoding_method)
            obj.siginfo = siginfo;
            obj.pos = 1;
            obj.size = 0;
            obj.encoding_method = encoding_method;
            obj.mex_support = mex_support;
        end

        function obj = reset(obj, block)
            obj.pos = 1;
            obj.block = block;
            obj.size = length(block.data);
           
        end

        function [obj, frame] = next(obj)
            if obj.size - obj.pos < obj.FRAME_HEADER_SIZE
                frame =[];
                return;
            end
            i = obj.pos-1;
            frame.block_id = obj.block.id;
            frame.id = obj.pos;
            frame.channel = typecast(obj.block.data(i+1:i+2),'uint16') + 1;
            frame.start_tick = typecast(obj.block.data(i+3:i+10),'int64');
            frame.size = int64(typecast(obj.block.data(i+11:i+14),'uint32'));
            frame.raw_size = typecast(obj.block.data(i+15:i+18),'uint32') + obj.FRAME_HEADER_SIZE;
            if obj.pos + frame.raw_size - 1 > obj.size
                error('SMLOADER:PARSE_FRAME','Frame size %d exceeds block boundary', frame.raw_size);
            end
            if (length(obj.siginfo) < frame.channel)
                error('SMLOADER:PARSE_FRAME', 'Unexpected channel: %d ?', frame.channel);
            end
            obj.pos = obj.pos + frame.raw_size;
        end

        function samples = decode(obj, frame)
            if obj.mex_support
                samples = obj.decode_with_mex(frame);
            else
                samples = obj.decode_slowly(frame);
            end
        end

        function samples = decode_with_mex(obj, frame)
            if frame.block_id ~= obj.block.id
                error('SMLOADER:DECODE_FRAME','unexpected frame to decode (block_id is invalid)');
            end
            if frame.channel > length(obj.siginfo)
                error('SMLOADER:DECODE_FRAME','Channel % is unspecifed and was skipped', frame.channel);
            end
            frame_data = obj.block.data(frame.id + obj.FRAME_HEADER_SIZE: frame.id + frame.raw_size-1);
            samples = smdecode(frame_data, frame.size, ...
                obj.siginfo{frame.channel}.max_bytes_per_sample, ...
                obj.siginfo{frame.channel}.uv_per_bit, obj.encoding_method);
        end
       
        
        function samples = decode_slowly(obj, frame)
            if frame.block_id ~= obj.block.id
                error('SMLOADER:DECODE_FRAME','unexpected frame to decode (block_id is invalid)');
            end
            if frame.channel > length(obj.siginfo)
                error('SMLOADER:DECODE_FRAME','Channel % is unspecifed and was skipped', frame.channel);
            end
            uv_per_bit = obj.siginfo{frame.channel}.uv_per_bit;
            MAX_BYTES = obj.siginfo{frame.channel}.max_bytes_per_sample;
            samples = zeros(1, frame.size, 'single');
            val = int32(0);
            tick_counter = 1;
            next_frame_pos = frame.id + frame.raw_size;
            i = frame.id + obj.FRAME_HEADER_SIZE;
            try
            while i < next_frame_pos && tick_counter <= frame.size
                if obj.block.data(i) ~= obj.INT8_MAX
                    val = val + int32(obj.block.data(i));
                    i = i + 1;
                else
                    i = i + 1;
                    diff = typecast(obj.block.data(i:i+1),'int16');
                    if MAX_BYTES == 2
                        val = int32(diff);
                        i = i + 2;
                    elseif  diff ~= obj.INT16_MAX 
                        val = val + int32(diff);
                        i = i + 2;
                    else 
                        % read 24 bit or 32 bit
                        i = i + 2;
                        if obj.encoding_method == 0 || MAX_BYTES == 4
                           val = typecast(obj.block.data(i:i+3),'int32');
                           i = i + 4; 
                        else  % encoding method 1 && MAX_BYTES = 3
                           val = idivide(typecast([obj.block.data(i:i+2); int8(0)],'int32'), 256);
                           i = i + 3;
                        end
                    end
                end
                samples(tick_counter)  = double(val)*uv_per_bit;
                tick_counter = tick_counter + 1;
            end
            catch ME
                warning(ME.message);
                % expected error - out of index - will be handled below
            end
            if i < next_frame_pos
                warning('SMLOADER:DECODE_FRAME','Unused data in frame (%d bytes). Frame may be corrupted', next_frame_pos - i);
            end
            if tick_counter ~= frame.size+1
                error('SMLOADER:DECODE_FRAME', 'Not enough data in frame. Frame may be corrupted');
            end
        end

    end %methods
end





