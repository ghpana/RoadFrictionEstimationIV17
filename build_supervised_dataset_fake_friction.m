%% Build supervised dataset
% Comment: Combine measurements from vehicles and weather station.
% The dataset is labeled and stores measurements each hour from the 
% last four hours (by default)
% Important variables with deafult values:
%
% Step size (in minutes)
% inc_min_step = 2
% Duration until last measurement
% prev_time = 60
% Set minimum quality level
% min_quality = 4
% Set maximum duration since last measurement in hours
% max_search_time = 5
% Set search region (for prev. measured friction values)
% search_region = 0.04
for loop = 0:30:120

%% Define date/time format
formatIn = 'yyyy-mm-dd HH:MM:SS';
formatIn2 = 'dd-mmm-yyyy HH:MM:SS';
formatIn3 = 'mm/dd/yyyy HH:MM';

% Set start and end date/time
starttime = '2015-11-01 14:44:06';
endtime = '2016-11-15 06:06:07';

%Step size (in minutes)
inc_min_step = 2;
% Duration until last measurement (default 60 min)
prev_time = 60;
% Set minimum quality level (inactive)
min_quality = 4;
% Set maximum duration since last measurement in hours (default 5 hours)  (inactive)
max_search_time = 5;
% Set search region (for prev. measured friction values) (defalt 0.04, gps
% coords (inactive)
search_region = 0.04;
offset_time = loop;

% Error check
if inc_min_step > prev_time
    error('Cannot handle prev_time time larger then inc_step')
end

% Get the start and end dates in serial date number
step_behind    = prev_time/inc_min_step;
firsttimemark  = datenum(starttime,formatIn);
current        = datenum(starttime,formatIn);
lasttime       = datenum(endtime,formatIn);

% Show start and end date/time
disp('Start time')
datestr(current,formatIn)
disp('End time')
datestr(lasttime,formatIn)


t1 = datevec(firsttimemark);
t2 = datevec(lasttime);
% Get number of time intervals from start to end date/time
nummins = etime(t2,t1)/60/inc_min_step;

%% Feature Index
% These are the indices for the different features
indFrictionValue   = 3;
indFrictionQuality = 4;

ind1PrevDistFriction     = 5;
ind1PrevTimeFriction     = 6;
ind1PrevFrictionValue    = 7;
ind1PrevFrictionQuality  = 65;

indTempSMHI    = 9;
indTempRoadVV  = 14;
indTempVV      = 19;
indHumidityVV  = 24;
indDewVV       = 29;
indRainVV      = 34;
indSnowVV      = 39;
indWindVV      = 44;
indWiperSpeedCar = 49;
indLog = 54;
indLat = 55;
indMappedLog = 56;
indMappedLat = 57;

ind2PrevDistFriction  = 58;
ind2PrevTimeFriction  = 59;
ind2PrevFrictionValue = 60;
ind3PrevDistFriction  = 61;
ind3PrevTimeFriction  = 62;
ind3PrevFrictionValue = 63;
indTempCar            = 64;

% Allocate some space
alldataset = zeros(fix(nummins),50);

%% Generate time marks
newdataset = zeros(fix(nummins),64);
current = datenum(starttime,formatIn);

for mins=1:nummins
    current_end = addtodate(current, inc_min_step, 'minute');
    newdataset(mins,1) = current;
    % Update the time mark
    current = current_end;
end

%% ADD Temperature data from SMHI
ftemp = fopen('../export/SMHITemp.csv','rt');
raw_temp = textscan(ftemp, ['%f %s %s ',repmat('%f',[1,1])],'Delimiter',',','headerLines', 0); %or whatever formatting your file is
fclose(ftemp);

%% Create datetime list in raw_temp
% Reformat the time stamp
disp('Create datetime list in raw_temp...')
numtemphours = length(raw_temp{1}(:));
for temphours=1:numtemphours
    if mod(temphours,200) == 0
        fprintf('%.2f %% done\n',temphours/numtemphours*100);
    end
    raw_temp{5}(temphours) = datenum([...
        strjoin(raw_temp{2}(temphours)) ' ' strjoin(raw_temp{3}(temphours))],...
        formatIn);
end

%% Load data from SMHI
disp('Load temperatures from SMHI dataset...')
% Dummy optimizer variable
lowestIndex = 2;

% Loop through all time intervals
for mins=1:nummins
    
    % Progress output
    if mod(mins,40) == 0
        fprintf('%.2f %% done\n',mins/nummins*100);
    end
    
    % Set an offset, used to build datasets for the forecast models
    current_offset = addtodate(newdataset(mins,1), -offset_time, 'minute');
    datestr(newdataset(mins,1));
    for temphours=lowestIndex:numtemphours-1
        
        % Optimize the search algorithm
        if current_offset < raw_temp{5}(temphours)
            break
        end
        if raw_temp{5}(temphours) < current_offset
            lowestIndex = temphours;
        end
        
        % Find matching measurement
        if (current_offset >= raw_temp{5}(temphours)) && ...
           (current_offset < raw_temp{5}(temphours+1))
            newdataset(mins,indTempSMHI) = raw_temp{4}(temphours);
        end
    end
end

 
%% Store previous temperatures (SMHI)
 newdataset(:,indTempSMHI+1) = [zeros(step_behind*1,1);newdataset(1:end-step_behind*1,indTempSMHI)];
 newdataset(:,indTempSMHI+2) = [zeros(step_behind*2,1);newdataset(1:end-step_behind*2,indTempSMHI)];
 newdataset(:,indTempSMHI+3) = [zeros(step_behind*3,1);newdataset(1:end-step_behind*3,indTempSMHI)];
 newdataset(:,indTempSMHI+4) = [zeros(step_behind*4,1);newdataset(1:end-step_behind*4,indTempSMHI)];


%% ADD data from Vagverket
fvv = fopen('../export/query_weatherstation_save_1435.csv','rt');
raw_vv = textscan(fvv, ['%f %f %s ',repmat('%f',[1,8]),' %s %f'],'Delimiter',',','headerLines', 0); %or whatever formatting your file is
fclose(fvv);

% Get number of time intervals
numvvhours = length(raw_vv{1}(:));

%% Load datenum info array col 1
for vvhours=1:numvvhours
    raw_vv{1}(vvhours) = datenum(raw_vv{3}(vvhours),formatIn3);
end


%% LOAD data from vagverket
disp('Load data from vagverket...')
lowestIndex = 2;
for mins=1:nummins
    
    % Progress output
    if mod(mins,40) == 0
        fprintf('%.2f %% done\n',mins/nummins*100);
    end
    
    % Set an offset, used to build datasets for the forecast models
    current_offset = addtodate(newdataset(mins,1), -offset_time, 'minute');
    
    for vvhours=lowestIndex:numvvhours-1

        % Optimize the search algorithm
        if current_offset < raw_vv{1}(vvhours)
            break
        end
        if raw_vv{1}(vvhours) < current_offset
            lowestIndex = vvhours;
        end
        
        % Find matching measurement
        if current_offset >= raw_vv{1}(vvhours) &&...
           current_offset < raw_vv{1}(vvhours+1)
       
            % Add Road heat
            newdataset(mins,indTempRoadVV) = raw_vv{4}(vvhours);
            % Add Air temperature
            newdataset(mins,indTempVV) = raw_vv{5}(vvhours);
            % Add Air Humidity
            newdataset(mins,indHumidityVV) = raw_vv{6}(vvhours);
            % Add Daggpunktstemperatur
            newdataset(mins,indDewVV) = raw_vv{7}(vvhours);
            
            % Add Regn & Snow
            if raw_vv{8}(vvhours) == 1
                newdataset(mins,indRainVV) = 0;
                newdataset(mins,indSnowVV) = 0;
            elseif raw_vv{8}(vvhours) == 2 || ...
                    raw_vv{8}(vvhours) == 3
                newdataset(mins,indRainVV) = raw_vv{9}(vvhours);
                newdataset(mins,indSnowVV) = 0;
            elseif raw_vv{8}(vvhours) == 4
                newdataset(mins,indRainVV) = 0;
                newdataset(mins,indSnowVV) = raw_vv{9}(vvhours);
            elseif raw_vv{8}(vvhours) == 6
                newdataset(mins,indRainVV) = raw_vv{9}(vvhours);
                newdataset(mins,indSnowVV) = raw_vv{9}(vvhours);
            else
                newdataset(mins,indRainVV) = 0;
                newdataset(mins,indSnowVV) = 0;
            end

            % Add Wind
            newdataset(mins,indWindVV) = raw_vv{13}(vvhours);
        end
    end
end


%% Clear data from vägverket
% Limit temperature
newdataset(newdataset(:,indTempRoadVV) < -30,indTempRoadVV) = mean(newdataset(:,indTempRoadVV));
% Limit humidity
newdataset(newdataset(:,indHumidityVV) < -30,indHumidityVV) = mean(newdataset(:,indHumidityVV));
% Cap Rain and Snow lvl at zero
newdataset(newdataset(:,indRainVV) < 0,indRainVV) = 0;
newdataset(newdataset(:,indSnowVV) < 0,indSnowVV) = 0;


%% Get previous measurements from...
% Road heat
% Airtemp
% Humidity
% Dew point temperature
% Rain
% Snow
% Wind speed
% Wiperspeed
counter = 15;
while counter < 53
    newdataset(:,counter) = [zeros(step_behind*1,1);newdataset(1:end-step_behind*1,counter-1)];
    counter = counter + 1;
    newdataset(:,counter) = [zeros(step_behind*2,1);newdataset(1:end-step_behind*2,counter-2)];
    counter = counter + 1;
    newdataset(:,counter) = [zeros(step_behind*3,1);newdataset(1:end-step_behind*3,counter-3)];
    counter = counter + 1;
    newdataset(:,counter) = [zeros(step_behind*4,1);newdataset(1:end-step_behind*4,counter-4)];
    counter = counter + 2;
end

%% Generate fake friction values
disp('Generate fake friction values')
mintemp = min(newdataset(:,indTempRoadVV));
maxtemp = max(newdataset(:,indTempRoadVV));
minhumidity = min(newdataset(:,indHumidityVV));
maxhumidity = max(newdataset(:,indHumidityVV));

difftemp = abs(maxtemp-mintemp)
diffhumidity = abs(maxhumidity-minhumidity)

sizedataset = size(newdataset,1);
index = 1;
for mins=1:nummins
    % Progress output
    if mod(mins,100) == 0
        fprintf('%.2f %% done\n',mins/nummins*100);
    end
    influence_temp = ((-(newdataset(mins,indTempRoadVV)-mintemp)/difftemp)+1);
    influence_humidity = ((-(newdataset(mins,indHumidityVV)-minhumidity)/diffhumidity)+1);

    newdataset(mins,indFrictionValue) = ((rand()*0.8-0)+...
        influence_temp+influence_humidity)/3;

    % Fetch data from 0.5, 1, 1.5 hours ago
    if mins<=30
        index = 1;
    else
        index = mins-30/inc_min_step;
    end
    influence_temp = ((-(newdataset(index,indTempRoadVV)-mintemp)/difftemp)+1);
    influence_humidity = ((-(newdataset(index,indHumidityVV)-minhumidity)/diffhumidity)+1);
    
    newdataset(mins,ind1PrevFrictionValue) = ((rand()*0.8-0)+...
        influence_temp+influence_humidity)/3;
    newdataset(mins,ind1PrevFrictionQuality) = 5;
    newdataset(mins,ind1PrevDistFriction) = 0.005;
    newdataset(mins,ind1PrevTimeFriction) = 30;

    if mins<=60
        index = 1;
    else
        index = mins-60/inc_min_step;
    end
    influence_temp = ((-(newdataset(index,indTempRoadVV)-mintemp)/difftemp)+1);
    influence_humidity = ((-(newdataset(index,indHumidityVV)-minhumidity)/diffhumidity)+1);
    newdataset(mins,ind2PrevFrictionValue) = ((rand()*0.8-0)+...
        influence_temp+influence_humidity)/3;
    newdataset(mins,ind2PrevDistFriction) = 0.01;
    newdataset(mins,ind2PrevTimeFriction) = 60;

    if mins<=90
        index = 1;
    else
        index = mins-90/inc_min_step;
    end
    influence_temp = ((-(newdataset(index,indTempRoadVV)-mintemp)/difftemp)+1);
    influence_humidity = ((-(newdataset(index,indHumidityVV)-minhumidity)/diffhumidity)+1);
    newdataset(mins,ind3PrevFrictionValue) = ((rand()*0.8-0)+...
        influence_temp+influence_humidity)/3;
    newdataset(mins,ind3PrevDistFriction) = 0.02;
    newdataset(mins,ind3PrevTimeFriction) = 90;
    
    % Remove some of the samples
    if randi([0,30]) ~= 0
        newdataset(mins,indFrictionValue) = 0;
    end
end


%% Remove datapoint if there is no friction value
% Copy newdataset
cleareddataset = newdataset;

% Get serial date number from start and end date
current = datenum(starttime,formatIn);
lasttime = datenum(endtime,formatIn);

disp('remove datapoints without friction value...')
cleareddataset((cleareddataset(:,indFrictionValue) == 0),:) = [];
cleareddataset((cleareddataset(:,ind1PrevFrictionValue) == 0),:) = [];


%% Prep data for plotting (not used)
removelowerpointsnot = 0;
tempnewdataset = newdataset;
tempalldataset = alldataset;
newdataset(newdataset(:,indFrictionValue)==0,indFrictionValue) = -10;
alldataset(alldataset(:,indFrictionValue)==0,indFrictionValue) = -10;

if removelowerpointsnot == 1
    newdataset = tempnewdataset;
    alldataset = tempalldataset;
end

    
%% Save cleareddataset as .csv and .mat
csvwrite(['cleareddataset' num2str(loop) '.csv'],cleareddataset)
save(['cleareddataset' num2str(loop) '.mat'])
end
