function e = get_elements(elements, name, varargin)
% get_elements Looks for set of elements of pointed Name in elements array 
% name ... path to target elements in element's name tree
% Example: elems = get_elements(elem_array, "Name", "Subname", ... ,"TargetName")
e = filter_elements(elements, name);
for i = 1 : length(varargin)
    e = filter_elements(parse_elements(e.data), varargin{i});
end
end

function res = filter_elements(elements, name)
% find_elements return array for elements of pointed name 
res = [];
if ~isempty(elements) > 0
    for i = 1:length(elements)
        if strcmp(elements(i).name, name)
            res = [res, elements(i)];
        end
    end
end
if isempty(res)
    error('SMLOADER:ELEMENT_NOT_FOUND', 'Element ''%s'' not found in block0', name);
end
end

