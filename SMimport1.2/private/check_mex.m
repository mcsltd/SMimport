function result = check_mex(mexname, test)
% chekmex check the mex function 
result = false;
if exist(mexname,"file") == 3
    if exist(test,"var")
        result = true;
    else
        try
            eval(test);
            result = true;
        catch 
        end
    end
end