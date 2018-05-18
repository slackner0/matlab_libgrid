% readsmheader - Read just the header information from a ShakeMap grid XML file.
% [hdrstruct,event] = readsmheader(filename);
% Input:
% - filename is a valid filename for a ShakeMap version 2 grid file
% Output:
% - hdrstruct is a Matlab structure, containing metadata about the grid data.
%   The fields are:
%   - ulxmap Upper left hand corner of upper left pixel X coordinate (decimal degrees).
%   - ulymap Upper left hand corner of upper left pixel X coordinate (decimal degrees).
%   - nrows  Number of rows in the grid.
%   - ncols  Number of rows in the grid.
%   - xdim Resolution in the X directioun (decimal degrees)
%   - ydim Resolution in the Y directioun (decimal degrees)
%   - nbands Number of bands.
%   - event is a Matlab struct containing the other interesting attributes 
%     found in the XML metadata: id,magnitude,lat,lon,depth,bandnames,bandunits,
%     time (as Matlab datenum), process_timestamp (as Matlab datenum), version and region name.
% - byteoffset (For use by readsmgrid) Byte offset before beginning of data
function [hdrstruct,event,byteoffset] = readsmheader(filename)
    hdrstruct(1) = struct();
    fid = fopen(filename,'rb');
    if (fid < 3)
     fprintf('Filename %s cannot be opened.\n');
     return;
    end

    %read the xml 'header' data in
    text = '';
    tline = fgets(fid);
    while (isempty(strfind(lower(tline),'<grid_data>')))
     text = [text tline];
     tline = fgets(fid);
    end
    %close the xml header
    text = [text '</shakemap_grid>'];

    %write that out to a temporary file...
    hdrfile = tempname();

    fid2 = fopen(hdrfile,'wt');
    fprintf(fid2,'%s',text);
    fclose(fid2);
    %read in back in with the xml parser, delete temp file
    dom = xmlread(hdrfile);
    delete(hdrfile);
    
    %parse out the stuff we're interested in, for now..
    %the grid_specification tag has most of what we need...
    gridspeclist = dom.getElementsByTagName('grid_specification');
    gridspec = gridspeclist.item(0);
    hdrstruct.nrows = str2num(gridspec.getAttribute('nlat'));
    hdrstruct.ncols = str2num(gridspec.getAttribute('nlon'));
    hdrstruct.ulxmap = str2num(gridspec.getAttribute('lon_min'));
    hdrstruct.ulymap = str2num(gridspec.getAttribute('lat_max'));

    xmin = hdrstruct.ulxmap;
    ymax = hdrstruct.ulymap;
    xmax = str2num(gridspec.getAttribute('lon_max'));
    ymin = str2num(gridspec.getAttribute('lat_min'));

    hdrstruct.xdim = str2num(gridspec.getAttribute('nominal_lon_spacing'));
    hdrstruct.ydim = str2num(gridspec.getAttribute('nominal_lat_spacing'));

    %the grid_field tags contain the other info
    gridfieldlist = dom.getElementsByTagName('grid_field');
    hdrstruct.nbands = gridfieldlist.getLength()-2; %don't include lat/lon
    gridlist = struct();
    for i=0:gridfieldlist.getLength()-1
     gridfield = gridfieldlist.item(i);
     gridlist(i+1).index = str2num(gridfield.getAttribute('index'));
     gridlist(i+1).name = char(gridfield.getAttribute('name'));
     gridlist(i+1).units = char(gridfield.getAttribute('units'));
    end


    event = struct();
    grideventlist = dom.getElementsByTagName('shakemap_grid');
    gridelement = grideventlist.item(0);
    event.id = char(gridelement.getAttribute('event_id'));

    %get the process timestamp from the grid.xml header
    event.process_timestamp = char(gridelement.getAttribute('process_timestamp'));
    event.process_timestamp = strrep(event.process_timestamp,'-','');
    event.process_timestamp = strrep(event.process_timestamp,':','');
    event.process_timestamp = strrep(event.process_timestamp,'Z','');
    event.process_timestamp = datenum(event.process_timestamp,'yyyymmddTHHMMSS');
    event.version = str2num(gridelement.getAttribute('shakemap_version'));

    eventlist = dom.getElementsByTagName('event');
    eventelement = eventlist.item(0);
    event.magnitude = str2num(eventelement.getAttribute('magnitude'));
    event.depth = str2num(eventelement.getAttribute('depth'));
    event.lat = str2num(eventelement.getAttribute('lat'));
    event.lon = str2num(eventelement.getAttribute('lon'));
    event.bandnames = {gridlist(3:end).name};
    event.bandunits = {gridlist(3:end).units};
    event.time = char(eventelement.getAttribute('event_timestamp'));
    event.region = char(eventelement.getAttribute('event_description'));
    event.type = char(gridelement.getAttribute('shakemap_event_type'));
    event.network = char(gridelement.getAttribute('shakemap_originator'));

    %convert the event.time to a Matlab datenum
    event.time = strrep(event.time,'-','');
    event.time = strrep(event.time,':','');
    event.time = strrep(event.time,'GMT','');
    event.time = datenum(event.time,'yyyymmddTHHMMSS');

    %Let's handle any arbitrary attributes we find in any of the header
    %elements, and add them as fields to the event structure.
    %shakemap_grid
    smgrid_atts = {'event_id','process_timestamp','shakemap_version',...
      'shakemap_event_type','shakemap_event_type',...
      'shakemap_originator'};
    attmap = gridelement.getAttributes();
    shakemap_grid = struct();
    for i=1:attmap.getLength()
      item = attmap.item(i-1);
      key = char(item.getNodeName());
      value = char(item.getNodeValue());
      if ismember(key,smgrid_atts) || ~isempty(strfind(key,':'))
          continue
      end
      if ~isempty(str2num(value))
          value = str2num(value);
      end
      shakemap_grid = setfield(shakemap_grid,key,value);
    end
    if length(fieldnames(shakemap_grid))
      event = setfield(event,'shakemap_grid',shakemap_grid);
    end

    %event
    event_atts = {'magnitude','depth','lat','lon','event_timestamp',...
      'event_description'};
    attmap = eventelement.getAttributes();
    subevent = struct();
    for i=1:attmap.getLength()
      item = attmap.item(i-1);
      key = char(item.getNodeName());
      value = char(item.getNodeValue());
      if ismember(key,event_atts)
          continue
      end
      if ~isempty(str2num(value))
          value = str2num(value);
      end
      subevent = setfield(subevent,key,value);
    end
    if length(fieldnames(subevent))
      event = setfield(event,'event',subevent);
    end

    %grid_specification
    gridspec_atts = {'nlat','nlon','lon_min','lat_max','lon_max','lat_min',...
      'nominal_lat_spacing','nominal_lon_spacing'};
    attmap = gridspec.getAttributes();
    gridspecstruct = struct();
    for i=1:attmap.getLength()
      item = attmap.item(i-1);
      key = char(item.getNodeName());
      value = char(item.getNodeValue());
      if ismember(key,gridspec_atts)
          continue
      end
      if ~isempty(str2num(value))
          value = str2num(value);
      end
      gridspecstruct = setfield(gridspecstruct,key,value);
    end
    if length(fieldnames(gridspecstruct))
      event = setfield(event,'grid_specification',gridspecstruct);
    end
    byteoffset = ftell(fid);
    fclose(fid);
end