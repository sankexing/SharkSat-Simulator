function [SolarPanels] = Call_STK_ModelSolarPanelPower(StartDate, EndDate,...
    TimeStep, COEs, SatEpochDate, ModelFileLocation, NumSolPanGroups, SolPanGroupNames)
% Jeremy Ogorzalek, 2019

% ~~ Description ~~
% This function estimates the power generated by a satellites solar panels.
% It is used when the satellite under consideration is not of a standard
% 6-sided 'cube-sat' form, and a custom model must be used. STK is called,
% the solar panel modeling tool is used, and the results are imported back
% to Matlab

% ~~ Notes ~~
% 

% ~~ Inputs ~~
% StartDate: String containing the start date of the analysis time period
% EndDate: String containing the end date of the analysis time period
% TimeStep: Granularity of the analysis. [s]
% COEs: Vector containing the six classical orbital elements. 
% SatEpochDate: String containing the epoch date, the date at which the 
% COEs are valid. ex '    '
% ModelFileLocation: File location of the satellite .cae model file
% NumSolPanGroups: Total number of satellite solar panel groups
% SolPanGroupNames: The names of the solar panel groups

% ~~ Outputs ~~
% SolarPanels: Array of the instantaneous power generation of each of the
% solar panel groups at each of the time steps [W]
% ------------------------------------------------------------------------


sma = COEs(1); % km = semi-major axis
ecc = COEs(2); % eccentricity
inc = COEs(3); % degrees = inclination
argper = COEs(4); % degrees = argument of perigee
RAAN = COEs(5); % degrees = right ascension of the ascending node
truan = COEs(6); % degrees = true anomaly

% Open the connection with STK. Try multiple versions
try
    app = actxserver('STK11.application');
catch
    try
        app = actxserver('STK10.application');
    catch
        try
            app = actxserver('STK12.application');
        catch
            disp('Could not reach either STK10, STK11, or STK12')
            return
        end
    end
end

root = app.Personality2;
app.Visible = 1;
root.NewScenario('Sim');
scen = root.CurrentScen;
scen.SetTimePeriod(StartDate,EndDate);
scen.Epoch = scen.StartTime;
root.Rewind;

% Insert satellite object, names 'Sat,' and set properties
sat = scen.Children.New(18,'Sat'); 
sat.SetPropagatorType('ePropagatorHPOP');
set(sat.Propagator,'Step',TimeStep);
sat.Propagator.InitialState.Representation.AssignClassical('eCoordinateSystemJ2000',sma,ecc,inc,argper,RAAN,truan);
sat.Propagator.InitialState.Epoch = SatEpochDate;
basic = sat.Attitude.Basic; % Set the attitude of the satellite
basic.SetProfileType('eProfileNadiralignmentwithECFvelocityconstraint')
sat.Propagator.Propagate;

root.UnitPreferences.Item('DateFormat').SetCurrentUnit('EpSec');

% Define the satellite model by the location of the .cae model file
model = sat.VO.Model;
model.ModelData.Filename = ModelFileLocation;

% Define each of the solar panel groups by number and name
StringSP = strcat("AddGroup ", SolPanGroupNames(1));
try
    for i = 2:length(SolPanGroupNames)
        StringSP = strcat(StringSP, " AddGroup ", SolPanGroupNames(i));
    end
catch
end
CharSP = convertStringsToChars(StringSP);        
        
% Run the solar panel analysis tool, and generate the data
root.ExecuteCommand('VO */Satellite/sat SolarPanel Visualization Radius On 1 ', CharSP, ' View On')        
root.ExecuteCommand('Window3D * SetRenderMethod Method PBuffer WindowID 2');
root.ExecuteCommand(['VO */Satellite/sat SolarPanel Compute "', StartDate, '" "', EndDate, '" ', num2str(TimeStep)]);
root.UnitPreferences.Item('Power').SetCurrentUnit('W');
SolarPanelsDP = sat.DataProviders.Item('Solar Panel Power').Exec(scen.StartTime,scen.StopTime,TimeStep);
thisSolarPanelGroup = SolarPanelsDP.Sections.Item(cast(NumSolPanGroups,'int32'));
SolarPanelTime = cell2mat(thisSolarPanelGroup.Intervals.Item(cast(0,'int32')).DataSets.GetDataSetByName('Time').GetValues);
SolarPanelPower = cell2mat(thisSolarPanelGroup.Intervals.Item(cast(0,'int32')).DataSets.GetDataSetByName('Power').GetValues);
SolarPanels = [SolarPanelTime, SolarPanelPower];


end