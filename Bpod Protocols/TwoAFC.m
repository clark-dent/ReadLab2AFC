function TwoAFC

global BpodSystem
global DA

load('Stimuli.mat');

inp = 1;
MCP = inputdlg('Enter Minimum Center Poke Time for this rat:','MinCenterPoke');
[MCP status] = str2num(MCP{1});

while ~status
    MCP = inputdlg(sprintf('ERROR: PLEASE ENTER TIME IN SECONDS.\nEnter Minimum Center Poke Time for this rat:'),'MinCenterPoke');
    [MCP status] = str2num(MCP{1});
end

if MCP>100
    MCP = MCP / 10^(ceil(log10(MCP)));
end

%% Set parameters for this protocol
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into workspace
if isempty(fieldnames(S))       % If the settings file is empty, load the following default settings
    S.GUI.RewardAmount = 200;   % microliters
    S.GUI.MinCenterPoke = MCP;  % Minimum length of initiation poke
    S.GUI.TimeoutDuration = 2;  % Duration of timeout for incorrect response
    S.GUI.MaxTrials = 1000;     % Maximum number of trials allowed per session
    s.GUI.FileID = 1;
end

% Initialize the parameter GUI plugin
BpodParameterGUI('init', S);

% Set sound condition parameters

FC1 = [4 8 11 23 45 64];     % Conditions for first burst
FC2 = [4];    % Conditions for second burst
AllStims = [4 8 11 23 45 64];   % All FCs contained in Stimuli.mat
StimLength = 117187;

IncrementTime = 0.0001;


nFC1 = length(FC1);
nFC2 = length(FC2);
% Generate random list of trial types; 50% type 1 (long-long), 50% all
% other types

TrialTypes = zeros(1,S.GUI.MaxTrials);
for tr = 1:length(TrialTypes)
    if rand() > 0.5
        TrialTypes(tr) = 1;
    else
        TrialTypes(tr) = 6;
    end
end
    
StimTable = zeros((nFC1*nFC2),2);
for q = 1:nFC1
    for r = 1:nFC2
        StimTable((q-1)*nFC2 + r,:) = [find(FC1(q)==AllStims) find(FC2(r)==AllStims)];
    end
end

            
%% Initialize Plots
BpodSystem.ProtocolFigures.OutcomePlotFig = figure('Position', [200 200 1000 300], 'name','Outcome Plot','numbertitle','off','MenuBar','none','Resize','off');
BpodSystem.GUIHandles.OutcomePlot = axes('Position', [0.075 .3 .89 .6]);
TrialTypeOutcomePlot(BpodSystem.GUIHandles.OutcomePlot,'init',TrialTypes);

BpodNotebook('init');   %Launches an interface to write notes about behavior and manually score trials

%% Load Buffer 1 for First Time
FileID1 = randi(25);


Stimulus1 = squeeze(Stimuli(StimTable(TrialTypes(1),1),StimTable(TrialTypes(1),2),FileID1,:))';

figure, set(gcf,'visible','off');
DA = actxcontrol('TDevAcc.X');
DA.ConnectServer('Local');              % Connect to TDT Software
DA.WriteTargetVEX('RZ6.Sound1',0,'F32',Stimulus1);    % Write first sound to Buffer 1
DA.SetTargetVal('RZ6.Trigger1',1);      % Activate Buffer 1 for the first time
DA.SetTargetVal('RZ6.Trigger2',0);      % Deactivate Buffer 2
DA.CloseConnection;     % Close connection to TDT software

S.GUI.FileID = FileID1;

%% Main Trial Loop
for currentTrial = 1:S.GUI.MaxTrials
    
    % Initialize TDT connection
    DA.ConnectServer('Local');
    

    S = BpodParameterGUI('sync', S);        % Sync parameters with BpodParameterGUI plugin
    R = GetValveTimes(S.GUI.RewardAmount, [1 3]); LeftValveTime=R(1); RightValveTime = R(2);    % Update solenoid valve open times for reward
    switch TrialTypes(currentTrial)         % Define which sound numbers do what.
        case 1
            LeftResponse = 'Timeout'; RightResponse = 'Reward'; RewardValve = 4; RewardWire = 4; LightCode= 'PWM3';
        
%          case 2
%              LeftResponse = 'Reward'; RightResponse = 'Timeout'; RewardValve = 1; RewardTime = RightValveTime; LightCode= 'PWM1';
%         case 3
%             LeftResponse = 'Reward'; RightResponse = 'Timeout'; RewardValve = 3; RewardTime = RightValveTime; LightCode= 'PWM1';
%         case 4
%             LeftResponse = 'Reward'; RightResponse = 'Timeout'; RewardValve = 3; RewardTime = RightValveTime; LightCode= 'PWM1';
%         case 5
%             LeftResponse = 'Reward'; RightResponse = 'Timeout'; RewardValve = 3; RewardTime = RightValveTime; LightCode= 'PWM1';
        case 6
            LeftResponse = 'Reward'; RightResponse = 'Timeout'; RewardValve = 1; RewardWire = 1; LightCode= 'PWM1';
            
    end
    sma = NewStateMatrix(); %Create new state matrix
    sma = SetGlobalTimer(sma, 1, 0.605);
    sma = AddState(sma, 'Name', 'WaitForPoke', ...
        'Timer', 0, ...
        'StateChangeConditions', {'Port2In', 'WaitMinPokeTime'}, ...
        'OutputActions', {'PWM2', 255});
    sma = AddState(sma, 'Name', 'WaitMinPokeTime', ...                                      % With nose in port 2, wait for rat to hold long enough (set by S.GUI.MinCenterPoke) and go to WaitForPoke
        'Timer', S.GUI.MinCenterPoke, ...                                                   % or if they withdraw too early, go back to WaitForPoke. Sets BNC channel 1 to on, to trigger
        'StateChangeConditions', {'Port2Out', 'RemainingSound', 'Tup', 'WaitForResponse'}, ...
        'OutputActions', {'BNCState', 1, 'GlobalTimerTrig', 1});
    sma = AddState(sma, 'Name', 'RemainingSound', ...
        'Timer', 0, ...
        'StateChangeConditions', {'GlobalTimer1_End', 'exit'}, ...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'WaitForResponse', ...                                      % After triggering a stimulus, wait for rat to poke left or right, and go to corresponding state.
        'Timer', 0, ...
        'StateChangeConditions', {'Port1In', LeftResponse, 'Port3In', RightResponse}, ...
        'OutputActions', {'WireState', RewardWire, 'ValveState', RewardValve});
    sma = AddState(sma, 'Name', 'Reward', ...                                           % If correct response, send reward to that port.
        'Timer', 0.1, ...                                           
        'StateChangeConditions', {'Tup', 'exit'}, ...
        'OutputActions', {});    
    sma = AddState(sma, 'Name', 'Timeout', ...                                               % If incorrect response, timeout for (S.GUI.TimeoutDuration) seconds. Trigger BNC port 2 to signal Pulse Pal
        'Timer', S.GUI.TimeoutDuration, ...                                                 % to activate timeout buzzer/light. When done, go to end.
        'StateChangeConditions', {'Tup', 'exit'}, ...
        'OutputActions', {'BNCState', 2});


    
    SendStateMatrix(sma);   % Send the state matrix to the Bpod
    
    RawEvents = RunStateMatrix;     % Make it so, Number One.
    if ~isempty(fieldnames(RawEvents))
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data, RawEvents);           % Add this trial's data to the struct
        BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data);                % Add info from the notebook
        BpodSystem.Data.TrialSettings(currentTrial) = S;                        % Add current trial parameters
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial);    % Add current trial type
        BpodSystem.Data.FileID(currentTrial) = S.GUI.FileID;
        UpdateOutcomePlot(TrialTypes, BpodSystem.Data);
        SaveBpodSessionData;        % Save it to current data file
    end
    
    % Load next stimulus    
    FileID = randi(25); % Choose randomly from 25 pre-generated files per condition
    S.GUI.FileID = FileID;  % Write file ID to GUI
    
%     StimFile = ['C:\Users\labadmin\Documents\MATLAB\Sounds\FC'...
%         num2str(StimTable(TrialTypes(currentTrial+1),1)) '_'...
%         num2str(StimTable(TrialTypes(currentTrial+1),2)) '_'...
%         num2str(FileID) '.wav']
%     Stimulus = audioread(StimFile)';  % Load stimulus from .wav file 
    
Stimulus = squeeze(Stimuli(StimTable(TrialTypes(currentTrial+1),1),StimTable(TrialTypes(currentTrial+1),2),FileID,:))';

    if rem(currentTrial,2)     % If odd-numbered trial, Buffer 1 was triggered
        DA.WriteTargetVEX('RZ6.Sound2',0,'F32',Stimulus);    % Write next sound to Buffer 2
        DA.SetTargetVal('RZ6.Trigger1',0);      % Deactivate Buffer 1
        DA.SetTargetVal('RZ6.Trigger2',1);      % Activate Buffer 2
    else                        % If even-numbered trial, Buffer 2 was triggered
        DA.WriteTargetVEX('RZ6.Sound1',0,'F32',Stimulus);    % Write next sound to Buffer 1
        DA.SetTargetVal('RZ6.Trigger2',0);      % Deactivate Buffer 2
        DA.SetTargetVal('RZ6.Trigger1',1);      % Activate Buffer 1 for next time
    end

    if ~isempty(fieldnames(RawEvents))
        if ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.WaitForResponse(1))
            S.GUI.MinCenterPoke = S.GUI.MinCenterPoke + IncrementTime;
        end
    end
    
    HandlePauseCondition;
    
    if BpodSystem.BeingUsed == 0
        return
    end
    
    DA.CloseConnection;     % Close connection to TDT software
    
end

    
function UpdateOutcomePlot(TrialTypes, Data)
global BpodSystem
Outcomes = zeros(1,Data.nTrials);
for x = 1:Data.nTrials
    if ~isnan(Data.RawEvents.Trial{x}.States.Reward(1))
        Outcomes(x) = 1;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.Timeout(1))
        Outcomes(x) = 0;
    else
        Outcomes(x) = 2;
    end
end
TrialTypeOutcomePlot(BpodSystem.GUIHandles.OutcomePlot,'update',Data.nTrials+1,TrialTypes,Outcomes);
    