% cleangeostruct Remove unnecessary fields from a geostruct structure, error if missing required fields.
% geostruct = cleangeostruct(geostruct);
% Input:
%  - geostruct  Geostruct structure, possibly containing fields other than:
%    - grid is a 1-N band cube of gridded data.
%    - nrows Number of rows in grid.
%    - ncols Number of columns in grid.
%    - nbands Number of bands in grid.
%    - ulxmap Upper left hand corner of upper left pixel X coordinate (decimal degrees).
%    - ulymap Upper left hand corner of upper left pixel X coordinate (decimal degrees).
%    - xdim Resolution in the X directioun (decimal degrees)
%    - ydim Resolution in the Y directioun (decimal degrees)
% Output:
%  - geostruct Structure containing only those fields listed above.
function geostruct = cleangeostruct(geostruct)
    
    gfields = fieldnames(geostruct);
    okfields = {'grid','bandnames','ulxmap','ulymap','xdim','ydim'};
    
    badfields = setxor(gfields,okfields);
    geostruct = rmfield(geostruct,badfields);
    
    hasfields = isfield(geostruct,okfields);
    if (sum(hasfields) ~= length(okfields))
      fprintf('Your geostruct is missing required fields.  Returning empty.\n');
      geostruct = struct();
      
    end
    
    return;