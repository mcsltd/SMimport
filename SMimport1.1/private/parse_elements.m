function res = parse_elements(buf)
% parse element 
% Parse buffer of block0 
% and return Elements struct array. Non recursive parsing!

elem = struct();
res = struct([]);
tail = length(buf);
pos = 1;
while pos <= tail
    % Выборка заголовка элемента
    [i, j] = regexp(buf(pos:end), '<\w+\s*', 'once');
    if isempty(i) || j >= tail
        break; % no more elements
    end
    i = i + pos - 1;
    j = j + pos - 1;
    if buf(j+1) == '>'
        % Элемент без атрибутов но с данными
        elem.name = strtrim(buf(i+1:j));
        elem.attributes = [];
        pos = j+2;
    elseif buf(j+1) == '/'
        % Элемент без атрибутов и без данных (пока таких не встречал)
        if buf(j+2) ~= '>'
            error('missing close tag');
        end
        elem.name = strtrim(buf(i+1:j));
        elem.attributes = [];
        elem.data = [];
        pos = j+3;
        continue;
    else
        % элемент с атрибутами
        elem.attributes = [];
        elem.name = strtrim(buf(i+1:j));
        while true
            [attrs, e] = regexp(buf(j:end), '(?<atrname>\w+)\s*=\s*"(?<atrval>[^"]*\x0?)"\s*', 'once','names','end');
            if isempty(attrs) 
                break;
            end
            elem.attributes = [ elem.attributes, attrs];
            j = e+j-1;
            if j>= tail || buf(j+1) == '>' || buf(j+1) == '/'
                break;
            end
        end
        if j== tail
            error('missing close tag');
        elseif buf(j+1) == '>'
            % элемент с данными
            pos = j+2;
        elseif buf(j+1) == '/'
            % элемент без данных
            elem.data = [];
            res = [res, elem];
            pos=j+2;
            continue
        else
            error('invalid element format')
        end
    end

    % Выборка данных
    endtag_exp = ['</\s*', elem.name, '\s*>'];
    [i, j] = regexp(buf(pos:end), endtag_exp, 'once');
    if isempty(i)
        error('missed close tag for element')
    end
    i = i + pos - 1;
    j = j + pos - 1;
    elem.data = strtrim(buf(pos: i-1));
    pos = j + 1;
    res = [res, elem];

end %while
end


