% STOCK  A Matlab class for obtaining stock quotes from Yahoo Finance. 
%
% Synopsis
%
%   STOCK(SYMBOL,PERIOD,FREQ) creates an object for the current quote
%       and historical prices for the stock denoted by SYMBOL. 
%   
%       SYMBOL  String, case insensitive, denoting desired stock.
%
%       PERIOD  String in the format ddd[dwmy] denoting the historical
%               period. Default is '5y'.
%
%       FREQ    String that is either 'm', 'w', or 'd' denoting
%               historical data freqeuncy. Default is 'w'.
%   
% Examples
%
%        X = stock('F') creates an object with the current quote and
%               five years of weekly price data for Ford.
%
%        X = stock('XOM','10y','m') creats an object with the
%               current quote and ten years of monthly historical price
%               information for Exxon-Mobile.
%
% Methods
%
%       stock('F').plot creates and plots the historical price data.
%
%       stock('F').garch creates and fits a GARCH model to the
%               historical price data. Requires the econometrics
%               toolbox.
%
%   Yahoo finance provides stock quotes through a url mechanism
%   involving various URL parameters. For more options, consult
%
%   http://www.diytraders.com/content/view/26/39/
%   http://www.etraderzone.com/free-scripts/50-yahoo-stock-quotes.html
%   http://www.goldb.org/ystockquote.html
%   http://finance.yahoo.com/exchanges

% Jeffrey Kantor
% Developed 2008-2010
%   11/20/2010  Added disp method and additional fields from yfinance
%   11/18/2010  First posted on Matlab Central

classdef (CaseInsensitiveProperties = true) stock < handle
    
    properties
        
        % Descriptive Information
        
        Symbol            % Symbol (String)
        Name              % Descriptive name (String)
        Source            % Source (String)
        Exchange          % Exchange (String)
        
        % Historical Data (ascending dates, i.e., most recent data is last)
        
        Freq              % Historical Date Frequency ('d','w','m','u')
                          %     'd'  daily
                          %     'w'  weekly
                          %     'm'  monthly
                          %     'u'  indeterminant
        Period            % Cell with Historical Period'\d*[dmy]' format
        Dates             % Historical dates in Matlab serial number format
                          %    in ascending order.
        Price             % Historical Price data. Adjusted prices for 
                          %    splits,dividends, settlements, or other 
                          %    adjustments needed to provide a useful 
                          %    longitudinal data series.
        Open              % Vector of Opening prices
        High              % Vector of High prices
        Low               % Vector of Low prices
        Close             % Vector of Close prices
        Volume            % Vector Volume
        AdjClose          % Vector of Adjusted Closing Prices. This is
                          %     is also stored in the Price field
        
        % Current Quote
        
        last_price        % Yahoo l1: Last Price
        last_date         % Yahoo d1: Last Trade Date
        last_time         % Yahoo t1: Last Trade Time
        day_change        % Yahoo c1: Change
        prev_close        % Yahoo  p: Previous Close
        day_open          % Yahoo  o: Open
        day_high          % Yahoo  h: Day's High
        day_low           % Yahoo  g: Day's Low
        day_volume        % Yahoo  v: Volume
        pe                % Yahoo  r: Price/Earnings Ratio
        peg               % Yahoo r5: Price to Earnings Growth
        div_yield         % Yahoo  y: Dividend Yield [%]
        year_low          % Yahoo  j: 52-Week Low
        year_high         % Yahoo  k: 52-Week High
                          
    end
    
    properties (Dependent = true)
        
        LogReturn         % Log return on historical prices. *Not annualized*
        Volatility        % Annualized volatility of Log Returns
        MeanLogReturn     % Mean Annualized Log return on historical prices. 
        
    end
    
    methods
        
        function q = stock(Symbol,Period,Freq)
            
            % Store Symbol as a Cell array
            
            q.Symbol = Symbol;
            
            % Validate and store date/data frequency. Default is 'w'
            
            if (nargin < 3) || isempty(char(Freq))
                Freq = 'w';
            else
                Freq = lower(strtrim(Freq));
                if ~ismember(Freq,{'d','m','w'})
                    error('Frequency must be ''d'',''m'', or ''w''');
                end
            end
            
            q.Freq = Freq;
            
            % Validate the Period string
            
            if (nargin < 2) || isempty(char(Period)) 
                Period = '3y';
            else
                Period = lower(strtrim(Period));
                [mat tok] = regexp(Period,'^(\d*)([dwmy])$','match','tokens');
                if isempty(mat)
                	error('Invalid Period Specification');
                end
            end
            
            q.Period = Period;
            
            % Get Data
   
            getQuote(q);
            getHistory(q);
            
        end % stock
        
        
        function getQuote(q)
            
            % Create URL and read response from Yahoo Finance
            
            [str,status] = urlread( ...
                ['http://finance.yahoo.com/d/quotes.csv?', ...
                sprintf('s=%s',char(q.Symbol)),'&f=snxl1d1t1c1pohgvrr5yjk']);
            
            if ~status
                error('Unable to read data from Yahoo Finance.');
            end
            
            s = stock.parseCSV(str);  
            
            q.Source      = 'Yahoo Finance';
            q.Symbol      = s{ 1};         % tag  s: Symbol
            q.Name        = s{ 2};         % tag  n: Name
            q.Exchange    = s{ 3};         % tag  x: Exchange
            
            q.last_price  = s{ 4};         % tag l1: Price of last trade
            q.last_date   = s{ 5};         % tag d1: Date of last trade
            q.last_time   = s{ 6};         % tag t1: Time of last trade
            q.day_change  = s{ 7};         % tag c1: Day change
            q.prev_close  = s{ 8};         % tag  p: Previous Close
            q.day_open    = s{ 9};         % tag  o: Day open
            q.day_high    = s{10};         % tag  h: Day high
            q.day_low     = s{11};         % tag  g: Day low
            q.day_volume  = s{12};         % tag  v: Day volume
            q.pe          = s{13};         % tag  r: Price/Earnings
            q.peg         = s{14};         % tag r5: Price/Earnings Growth
            q.div_yield   = s{15};         % tag  y: Dividend Yield
            q.year_low    = s{16};         % tag  j: 52-Week Low
            q.year_high   = s{17};         % tag  k: 52-Week High
            
        end % getQuote
        
        function getHistory(q, Period, Freq)
            
            % Parse arguments. This function may be used to update the
            % history of an existing object, so need to validate input
            % arguments.
            
            if nargin < 3
                Freq = q.Freq;
            else
                Freq = lower(strtrim(Freq));
                if ~ismember(Freq,{'d','m','w'})
                    error('Frequency must be ''d'',''m'', or ''w''');
                end
                q.Freq = Freq;
            end
            
            if nargin < 2 || isempty(Period)
                Period = q.Period;
            else
                Period = lower(strtrim(Period));
            end
            
            [mat tok] = regexp(Period,'^(\d*)([dwmy])$','match','tokens');
            if isempty(mat)
                error('Invalid Period Specification');
            end
            
            q.Period = Period;
            
            switch tok{1}{2}
                case 'd'
                    n = 1;
                case 'w'
                    n = 7;
                case 'm'
                    n = 365.25/12;
                case 'y'
                    n = 365.25;
            end
            
            startDate = datenum(date) - round(n*str2num(tok{1}{1}));
            [startYear,startMonth,startDay] = datevec(startDate);
            
            % Construct Yahoo url
            
            urlstr = ['http://ichart.finance.yahoo.com/table.csv?',...
                '&s=', q.Symbol, ...
                '&a=', num2str(startMonth-1), ... % Start Month-1
                '&b=', num2str(startDay),...      % Start Day
                '&c=', num2str(startYear), ...    % Start Year
                '&g=', Freq]; % Frequency (d->daily, w->weekly, m->monthly, 

            % Read url and parse into a cell array of individual lines
            
            s = textscan(urlread(urlstr),'%s','delimiter','\n');
            s = s{1};
            
            % Skip the first line, then parse each line into fields
            
            n = length(s) - 1;
            h = zeros(n,7);
            for k = 1:n;
                t = textscan(s{k+1},'%s%f%f%f%f%f%f','delimiter',',');
                t{1} = datenum(t{1});
                h(k,:) = cell2mat(t);
            end
            
            % Reverse order so oldest data at the top of the columns
            
            q.Dates    = h(end:-1:1,1);
            q.Open     = h(end:-1:1,2);
            q.High     = h(end:-1:1,3);
            q.Low      = h(end:-1:1,4);
            q.Close    = h(end:-1:1,5);
            q.Volume   = h(end:-1:1,6);
            q.AdjClose = h(end:-1:1,7);
            
            % Put Yahoo Adjusted Close in the "Price" field for subsequent
            % analysis and model fitting
            
            q.Price = q.AdjClose;
            
        end % getHistory
       
        
        function plot(q,vargin)
            
            figure(1);
            subplot(3,1,1)
            semilogy(q.Dates,q.Price);
            title(sprintf('%s: %s',q.Exchange,q.Name));
            ylabel('Adjusted Close');
            datetick('x',10);
            grid;
            
            subplot(3,1,2)
            plot(q.Dates,q.LogReturn);
            title(sprintf('Historical Volatility = %6.3f',q.Volatility));
            ylabel('Log Return');
            datetick('x',10);
            grid;
            
            subplot(3,1,3)
            plot(q.Dates,q.Volume);
            xlabel('Date'); ylabel('Volume');
            datetick('x',10);
            grid;
            
        end % plot
        
        
        function r = get.LogReturn(q)
        % Compute Log Return using Price data
            [n,m] = size(q.Price);
            if n > 1
                r = [zeros(1,m);diff(log(q.Price))];
            elseif n == 1
                r = [zeros(1,m)];
            else
                r = [];
            end    
        end % get.LogReturn
        
        
        function r = get.Volatility(q)
        % Computation of Historical Volatility. Computes the mean
        % differences in Dates, then annualizes the Volatility
            r = std(q.LogReturn)*sqrt(365.25/mean(diff(q.Dates)));      
        end % get.Volatility
        
        
        function r = get.MeanLogReturn(q)
        % Computation of Historical Log Return. Computes the mean
        % differences in Dates, then annualizes the Log Return
            r = mean(q.LogReturn)*(365.25/mean(diff(q.Dates)));      
        end % get.MeanLogReturn
        
        
        function disp(q)
            s = sprintf('%-17s (%s:%s)\n',q.Name,q.Exchange,q.Symbol);
            s = [s,sprintf('-----------------------------------------------\n')];
            s = [s,sprintf('Last Trade:         %6.2f',q.last_price)];
            s = [s,sprintf('  (%s %s)\n',q.last_time,q.last_date)];
            s = [s,sprintf('Daily Change:       %6.2f  (%4.2f%%)\n', ...
                           q.day_change, 100*(q.last_price-q.prev_close)/q.prev_close)];
            s = [s,sprintf('Prev. Close:        %6.2f\n',q.prev_close)];
            s = [s,sprintf('Day Open:           %6.2f\n',q.day_open)];
            s = [s,sprintf('Day Range:          %6.2f - %6.2f\n',q.day_low,q.day_high)];
            s = [s,sprintf('52wk Range:         %6.2f - %6.2f\n',q.year_low,q.year_high)];
            if ischar(q.pe)
                s = [s,sprintf('P/E                 %6s\n',q.pe)];
            else
                s = [s,sprintf('P/E                 %6.2f\n',q.pe)];
            end
            if ischar(q.div_yield)
                s = [s,sprintf('Dividend Yield      %6s\n',q.div_yield)];
            else
                s = [s,sprintf('Dividend Yield      %6.2f%%\n',q.div_yield)];
            end
            
            p.('d') = 'Daily';
            p.('w') = 'Weekly';
            p.('m') = 'Monthly';
            
            s = [s,sprintf('\n%s Price History: %s to %s\n',p.(q.Freq),datestr(min(q.Dates)),datestr(max(q.Dates)))];
            s = [s,sprintf('------------------------------------------------\n')];
            s = [s,sprintf('Volatility:         %6.2f%% (annualized)\n',100*q.Volatility)];
            s = [s,sprintf('Mean Log Return:    %6.2f%% (annualized)\n',100*q.MeanLogReturn)];
            disp(s);
        end % disp
%       
        
        function garch(q)
        % GARCH Use the Econometrics toolbox to fit a GARCH model to the
        % historical log returns
            [Coeff,Errors,LLF,Innovations,Sigmas,Summary] = ...
                garchfit(q.LogReturn);

            subplot(2,1,1);
            plot(q.Dates,Innovations);
            title(q.Name);
            ylabel('Innovations');
            datetick('x',10);
            
            subplot(2,1,2);
            plot(q.Dates,Sigmas);
            ylabel('Sigma');
            datetick('x',10);
            
            figure;
            qqplot(Innovations);
            
        end % function
  
    end % methods
    
    methods(Static)

        % s = parseCSV(str)
        %   Given a string in .csv format, parses the string into a cell
        %   array. Quotes are removed from double quote delimited fields.
        %   Number fields are converted to double.  This function is used
        %   to parse the records returned from Yahoo Finance.
        
        function s = parseCSV(str)
            
            % Trim any leading or trailing white space
            str = strtrim(str);
            
            % Regular expression parsing of csv string matching quoted,
            % unquoted, and null fields. Return cell array of fields
            s = regexp(str,'\"([^\"]+?)\",?|([^,]+),?|,','match');
            
            % Clean up each field
            for k = 1:length(s)
                
                % Remove trailing comma, leading and trailing white space
                s{k} = regexprep(s{k},',$','');
                s{k} = strtrim(s{k});
                
                % Remove any surrounding quotes
                v = s{k};
                if length(v) > 1
                    if v(1)=='"'
                        v = v(2:length(v)-1);
                    end
                    s{k} = v;
                end
                
                % If possible, convert to double
                v = str2double(s{k});
                if ~isnan(v)
                    s{k} = v;
                end
            end 
            
        end % parseCSV 
        
    end
end


