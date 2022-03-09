% read in the raw data
[num,txt,raw] = xlsread('EV-Charging-Raw-Data.csv');
% data = [Station, StartDate, EndDate, TransectionDate, Duration, 
% ChargingTime, Energy(kW), GHGSavings(kg), GasSavings(gallons), 
% PortNum, Fee, EndedBy, EventID, DriverPostal, UserID];
data = raw;
data(:,[2 3 5 7 14 16 17 18 19 20 21 22 23 24 25]) = [];

% driving distance calculation
driveDist = xlsread('Driving Distance.xlsx','sheet1','A3:C86');
temp1 = unique(num(:,21));
[temp2,ia,ic] = unique(num(:,22));

% custData = [custID, postal codes, distance];
custData = [num(ia,22) num(ia,21)];
custData(isnan(custData(:,1)),:) = [];
custData(1,:) = [];
custData(isnan(custData(:,2)),:) = [];
custNum = size(custData,1);
for i = 1:custNum
    custData(i,3) = driveDist(ismember(driveDist(:,2),custData(i,2)),3);
end

% cut off distance that is 135km or above
custData(custData(:,3)>=120,:) = [];

% sessTime = [start time, end time, duration minutes, user ID, Energy, port ID];
sessTime = zeros(size(raw,1)-1,6+6+1+1);
for i = 1:size(sessTime,1)
    sessTime(i,1:6) = datevec(raw{i+1,4});
    sessTime(i,7:12) = datevec(raw{i+1,6});
    sessTime(i,13) = (datenum(raw{i+1,6})-datenum(raw{i+1,4}))*24;
    sessTime(i,14) = raw{i+1,30};
    sessTime(i,15) = raw{i+1,11}; % kWh
    sessTime(i,16) = raw{i+1,15};
end
sessTime(sessTime(:,13)<1/60,:) = []; % get rid of 0 minute charging events



%% study the fee
fee1 = 0.85;
fee2 = 5;
sessHour = zeros(size(sessTime,1),5);
sessHour(:,1) = ceil(sessTime(:,13));
sessHour(sessHour(:,1)>4,2) = fee1*4;
sessHour(sessHour(:,1)>4,3) = (sessHour(sessHour(:,1)>4,1)-4)*fee2;
sessHour(sessHour(:,1)<=4,2) = sessHour(sessHour(:,1)<=4,1)*0.85;
sessHour(:,4) = sessHour(:,2) + sessHour(:,3);

TotalFee = sum(sessHour(:,2:4))

%% study the distribution of charging behaviors
sessDist = sessTime(sessTime(:,13)<15&sessTime(:,13)>5/60,:);
hist(sessDist(:,13),20);
% looks like the charging time distribution is a weibull distribution
pd = fitdist(sessDist(:,13),'Weibull');
X = 0:0.1:15;
Y = wblpdf(X,pd.A,pd.B);
figure
plot(X,Y)

figure
hist(sessDist(:,13),15);
hold on
X = 0:0.1:15;
Y = wblpdf(X,pd.A,pd.B);
Y = Y*size(sessDist,1);
plot(X,Y)

%% study the charing time Vs. driving distances
for i = 1:size(custData,1)
    custData(i,4) = mean(sessTime(sessTime(:,14)==custData(i,1),13));
end
X = custData;
X(isnan(X(:,4)),:) = [];
figure
scatter(X(:,3),X(:,4));
% charging distance Vs driving distance
figure
% I need to find a map of charging time vs. driving distances
scatter(X(:,3),X(:,4)*30);
hold on
plot([0,100],[0,100])
plot([0,100],[117,117]) % effective range of leaf is arount 117 mile

%% study the charging energy Vs. driving distances
for i = 1:size(custData,1)
    custData(i,5) = mean(sessTime(sessTime(:,14)==custData(i,1),15));
end
X = custData;
X(isnan(X(:,5)),:) = [];
figure
scatter(X(:,3),X(:,5));% total capacity of leaf is 21.3kWh
hold on
plot([0,100],[21.3,21.3]) % total capacity of leaf is 21.3kWh
plot([0,100],[0,100/117*21.3]) % assume charging energy to cover driving distance
plot([0,100],[0,200/117*21.3]) % no need to charge at home

% study the charging distance Vs. driving distances
figure
scatter(X(:,3),X(:,5)/21.3*117);% total capacity of leaf is 21.3kWh
hold on
plot([0,100],[0,100])

%% study the charging time Vs. charging energy
X = sessDist;
X(isnan(X(:,13)),:) = [];
X(isnan(X(:,15)),:) = [];
figure
scatter(X(:,15),X(:,13));
hold on
plot([0,100],[21.3,21.3]) % total capacity of leaf is 21.3kWh

%% study the arriving time distribution
figure
histogram(sessDist(:,4))
axis([0 23 0 180])

%% study the oqupation rate

sessDist1 = sessDist(sessDist(:,16)==1,:);
sessDist2 = sessDist(sessDist(:,16)==2,:);

sessTime1 = datenum(sessDist1(:,1:6));
sessTime1(:,2) = datenum(sessDist1(:,7:12));
sessTime2 = datenum(sessDist2(:,1:6));
sessTime2(:,2) = datenum(sessDist2(:,7:12));

startTime = min(datenum(sessDist(:,1:6)));
endTime = max(datenum(sessDist(:,7:12)));

temp1 = 0; % two vehicles charging
for i = 1:size(sessTime1,1)
    for j = 1: size(sessTime2,1)
        if sessTime2(j,1)<sessTime1(i,1) && sessTime2(j,2)>sessTime1(i,1)
            if sessTime2(j,2)<sessTime1(i,2) 
                temp1 = temp1+ sessTime2(j,2)-sessTime1(i,1);
            end
            if sessTime2(j,2)>sessTime1(i,2)
                temp1 = temp1+ sessTime1(i,2)-sessTime1(i,1);
            end
        end
        if sessTime2(j,1)>sessTime1(i,1) && sessTime2(j,1)<sessTime1(i,2)
            if sessTime2(j,2)<sessTime1(i,2) 
                temp1 = temp1+ sessTime2(j,2)-sessTime2(j,1);
            end
            if sessTime2(j,2)>sessTime1(i,2)
                temp1 = temp1+ sessTime1(i,2)-sessTime2(j,1);
            end
        end
    end
end

temp2 = 0; % at least one vehicle charging
for i = 1:size(sessTime1,1)
    temp2 = temp2 + sessTime1(i,2) - sessTime1(i,1);
end
for i = 1:size(sessTime2,1)
    temp2 = temp2 + sessTime2(i,2) - sessTime2(i,1);
end
temp2 = temp2 - temp1;
temp3 = endTime - startTime;


pie = temp1; % two charging
pie(2) = temp2 - temp1; % one charging
pie(3) = temp3 - temp2; % no charging


%% 






















