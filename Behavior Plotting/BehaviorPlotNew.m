function [ PercentCorrect, Trials ] = BehaviorPlotNew
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



TempData = zeros(RatCount,DayCount,2,2);
HoldCount = zeros(RatCount,DayCount);

for FileNum = 1:length(FileNames)
    
   FName = FileNames{FileNum};
        
   load([PathName FName])
   Rat = RatNums(FileNum);
   Day = DayNums(FileNum) - FirstDay + 1;
   
   Session = SessionNums(FileNum);
   %ConditionList = SessionData.Conditions
   ConditionList = {'FC4_4' 'FC6_64' 'FC11_64' 'FC23_64' 'FC45_64' 'FC4_64'};
   

   
   for TrialNum = 1:SessionData.nTrials
       
       Dur = SessionData.RawEvents.Trial{TrialNum}.States.WaitMinPokeTime(2) - SessionData.RawEvents.Trial{TrialNum}.States.WaitMinPokeTime(1);
              
       TempData(Rat,Day,Session,TrialNum,1) = Dur;
       
       if ~isnan(SessionData.RawEvents.Trial{TrialNum}.States.WaitForResponse(1))
           TempData(Rat,Day,Session,TrialNum,2) = 1;
       end
  
   end  % End loop for all trials

    
end     % End loop for all files



%% Plot Trial Durations

figure
hold on

x = [min(DayNums):max(DayNums)];
labels = [];

for ff = unique(RatNums)
    
    if ff < 10
        labels = [labels; ['Rat 0' num2str(ff)]];
    else
        labels = [labels; ['Rat ' num2str(ff)]];
    end

    z = squeeze(TempData(ff,:,:,:,:));
    z = squeeze(reshape(z,DayCount,1,[],2));
    
    y = (sum(z(:,:,1),2) ./ sum(z(:,:,1)~=0,2)) * 1000;
    
    plot(x,y)
end

xlabel('Day')
ylabel('Duration (ms)')
title('Average Center Hold Duration')
datetick('x','mmm-dd')
legend(labels)
grid on

refline(0,600)

ylim([0 700])

hold off

%% Plot Number of Correct Center Holds

figure
hold on

for gg = unique(RatNums)
    
    z = squeeze(TempData(gg,:,:,:,:));
    z = squeeze(reshape(z,DayCount,1,[],2));
    
    y = sum(z(:,:,2),2);
    y(y==0) = nan;
    plot(x,y)

end
xlabel('Day')
ylabel('Number of Holds')
ylim([0 300])
title('Number of Correct Center Port Holds')
datetick('x','mmm-dd')
legend(labels)
grid on

%% Plot center hold duration on correct holds

figure
hold on

for gg = unique(RatNums)
    
    
    z = squeeze(TempData(gg,:,:,:,:));
    z = squeeze(reshape(z,DayCount,1,[],2));
    
    for hh = 1:DayCount
        zd = squeeze(z(hh,:,:));
        zd = mean(zd(find(zd(:,2)==1)));
        y(hh) = zd * 1000;
    y(y==0) = nan;
    
    
    end
    
plot(x,y)
    
end

xlabel('Day')
ylabel('Duration')
title('Average Duration of Full Center Holds (ms)')
ylim([140 650])
datetick('x','mmm-dd')
legend(labels,'Location','Northwest')
grid on

end
