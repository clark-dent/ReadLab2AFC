function [ PercentCorrect, Trials ] = BehaviorPlot
%UNTITLED8 Summary of this function goes here
%   Detailed explanation goes here



%% Get Bpod Output Files

[FileNames,PathName] = uigetfile('*.mat','Select Bpod Output Files to Add','MultiSelect','on','C:\Users\labadmin\Documents\MATLAB\Today''s Data');
if isequal(FileNames,0)
    disp('User selected Cancel')
    return
else
    disp('User selected: ')
    disp(FileNames)
end

%% Extract File Parameters

RatNums = [];
DayNums = [];
SessionNums = [];

for FileNum = 1:length(FileNames);
    
    FName = FileNames{FileNum};
        
    RatNums(FileNum) = str2num(FName(12:14));
    TrialDay = FName(23:27);
    TrialYear = FName(29:32);
    DayNums(FileNum) = datenum([TrialDay TrialYear],'mmmddyyyy');     % Generates integer day number (730,000-ish)
    SessionNums(FileNum) = str2num(FName(end-4));
            
end

SessionCount = length(unique(SessionNums));
RatCount = max(RatNums);
DayCount = max(DayNums)-min(DayNums) + 1;
FirstDay = min(DayNums);

%% Extract File Data



TempData = cell(RatCount,DayCount,SessionCount);


for FileNum = 1:length(FileNames)
    
   FName = FileNames{FileNum};
        
   load([PathName FName])
   Rat = RatNums(FileNum);
   Day = DayNums(FileNum) - FirstDay + 1;
   
   Session = SessionNums(FileNum);
   %ConditionList = SessionData.Conditions
   ConditionList = {'FC4_4' 'FC6_64' 'FC11_64' 'FC23_64' 'FC45_64' 'FC4_64'};
   
   BlankStruc = struct();
   for q = 1:length(ConditionList)
       BlankStruc.(ConditionList{q}) = [0 0 0];
   end
   ix = cellfun('isempty',TempData);
   TempData(ix) = {BlankStruc()};
   
   for TrialNum = 1:SessionData.nTrials
       
       Condition = char(ConditionList(SessionData.TrialTypes(TrialNum)));

       if ~isnan(SessionData.RawEvents.Trial{TrialNum}.States.Reward)   % Check each condition (Reward/Timeout/else withdraw) and increment correct value in TempData
           TempData{Rat,Day,Session}.(char(Condition))(1) = TempData{Rat,Day,Session}.(char(Condition))(1) + 1;
           
       elseif ~isnan(SessionData.RawEvents.Trial{TrialNum}.States.Timeout)
           TempData{Rat,Day,Session}.(char(Condition))(2) = TempData{Rat,Day,Session}.(char(Condition))(2) + 1;
           
       else
           TempData{Rat,Day,Session}.(char(Condition))(3) = TempData{Rat,Day,Session}.(char(Condition))(3) + 1;
       end  
       
   end  % End loop for all trials

    
end     % End loop for all files


%% Plot Percent Correct
hold on

labels = {};
PercentCorrect = [];

PercData = permute(TempData,[1 3 2]);

for Cond = 1:length(ConditionList)
    
    Condition = char(ConditionList(Cond));
    
    
    y = zeros (RatCount,DayCount);
    x = [min(DayNums):max(DayNums)];
    labels = [];
    
    for j = unique(RatNums)
        
        if j < 10
            labels = [labels; ['Rat 0' num2str(j)]];
        else
            labels = [labels; ['Rat ' num2str(j)]];
        end
        
        for k = 1:DayCount
        
            z = [TempData{j,k,:}];
            z = [z.(Condition)];
            z = sum(reshape(z,SessionCount,3)',1);

            y(j,k) = z(1)/sum(z);
        end
            
    end
    
	figure(Cond)
    hold on
    str = ConditionList(Cond);
    expr = '\_';
    graphTitle = regexp(str,expr,'split');
    graphTitle = ['Percent Correct Responses ' graphTitle{1}{1} ' ' graphTitle{1}{2}];
    title(graphTitle)
    xlabel('Day')
    ylabel('Percent Correct')    

%     y(isnan(y)) = 0;
    plot(x,y(unique(RatNums),:))
    
	datetick('x','mmm-dd')
    legend(labels)
    
    hold off
end

 
%% Plot Trials

yy = zeros (RatCount,DayCount);
x = [min(DayNums):max(DayNums)];

for j = unique(RatNums)
    
    for k = 1:DayCount
        
        z = [TempData{j,k,:}];
        z = sum(struct2array(z));
        
        yy(j,k) = z;
    end
        
end

figure(Cond+1)
hold on
title('Total Trials')
xlabel('Day')

% yy(isnan(yy)) = 0;
yy(yy==0) = nan;

plot(x,yy(unique(RatNums),:))

datetick('x','mmm-dd')
legend(labels)

hold off


%% Plot Successful Center Pokes


PercentCorrect = y;
Trials = yy;

end


        
