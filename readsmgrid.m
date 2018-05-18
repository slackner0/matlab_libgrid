% readsmgrid - Read ShakeMap version 2 output grid files.
% [geostruct,event] = readsmgrid(filename);
% Input:
%  - filename is a valid filename for a ShakeMap version 2 grid file
% Output:
%  - geostruct is a Matlab structure, containing grid data and metadata
%  describing it.  The fields are:
%    - grid is a 4 band cube, with the N "layers" of the shakemap data
%      (described in grid.bandnames).
%    - ulxmap Upper left hand corner of upper left pixel X coordinate (decimal degrees).
%    - ulymap Upper left hand corner of upper left pixel X coordinate (decimal degrees).
%    - xdim Resolution in the X directioun (decimal degrees)
%    - ydim Resolution in the Y directioun (decimal degrees)
%    - bandnames Cell array of name of each band.
%  - event is a Matlab struct containing the other interesting attributes 
%  found in the XML metadata: id,magnitude,lat,lon,depth,bandnames,bandunits,
%  time (as Matlab datenum), process_timestamp (as Matlab datenum), version and region name.
function [geostruct,event] = readsmgrid(filename)
    %Read all of the information from the file header
    [hdrstruct,event,byteoffset] = readsmheader(filename);
        
    %make convenient temp variables
    nrows = hdrstruct.nrows;
    ncols = hdrstruct.ncols;
    grid = zeros(nrows,ncols,hdrstruct.nbands);
    ulx = hdrstruct.ulxmap;
    uly = hdrstruct.ulymap;

    xdim = hdrstruct.xdim;
    ydim = hdrstruct.ydim;

    %now read in the rest of the file
    fid = fopen(filename,'rb');
    fseek(fid,byteoffset,'bof');
    fmt = strtrim(repmat('%f ',1,hdrstruct.nbands+2));
    tline = fgets(fid); %read first data line
    pat = '</grid_data>';
    res = isempty(strfind(lower(tline),pat));
    while (res)
        data = textscan(tline,fmt); %cell array
        data = [data{1,:}]; %convert to matrix
        lon = data(1);
        lat = data(2);
        col = round(((lon - ulx)/xdim)+1);
        row = round(((uly - lat)/ydim)+1);
        if (col < 1)
            col = 1;
        end
        if (col > ncols)
            col = ncols;
        end
        if (row < 1)
            row = 1;
        end
        if (row > nrows)
            row = nrows;
        end
        grid(row,col,:) = data(3:end);
        tline = fgets(fid);
        res = isempty(strfind(lower(tline),pat));
    end
    fclose(fid);

    %can't trust xdim/ydim from shakemap, so we need to calculate it for
    %ourselves...
    %hdrstruct.xdim = (xmax - xmin)/hdrstruct.ncols;
    %hdrstruct.ydim = (ymax - ymin)/hdrstruct.nrows;

    geostruct = struct();
    geostruct.grid = grid;
    geostruct.bandnames = event.bandnames;

    fnames = fieldnames(hdrstruct);
    for i=1:length(fnames)
     fvalue = getfield(hdrstruct,fnames{i});
     geostruct = setfield(geostruct,fnames{i},fvalue);
    end
    geostruct = cleangeostruct(geostruct);
    return;
  