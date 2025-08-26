% Compiling with MSVC and without CRT dependency
% to avoid user have not specific version of Microsoft Visual C++ Redistributable
mex -R2018a  COMPFLAGS="$COMPFLAGS /MT /Ox" LDFLAGS="/NODEFAULTLIB" smcrc32.c
mex -R2018a  COMPFLAGS="$COMPFLAGS /MT /Ox" LDFLAGS="/NODEFAULTLIB" smdecode.c
