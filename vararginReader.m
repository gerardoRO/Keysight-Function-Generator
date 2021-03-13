%Created by Gerardo Rodriguez Orellana, circa 2017. Functions allows for
%parsing of variable inputs to a desired function, and returns a structure
%with any updated values. 

function variables = vararginReader(varargin)
% This function processes all variable inputs into different
% functions. It allows multiple fields as well as pre-defining them
% within a function while allowing overwriting capabilities. 

variables = struct; %predefine empty values
inputs = varargin{1}; %extract all the fields that were passed to the parent function

if nargin == 2 && isstruct(varargin{2}); variables = varargin{2}; end %pre-existing variables are inputted
if isempty(inputs); return; end %no inputs return empty variables


if isstruct(inputs{1}) %if varargin is already passed as a struct either append or return 
    new_fields = fieldnames(inputs{1}); %extract all new fields
    for field = 1:length(new_fields) %iterate through fields and append/edit
        eval(sprintf('variables.%s = getfield(inputs{1},new_fields{field});',lower(new_fields{field})));
    end
    return;

elseif length(inputs) > 1 %if multiple values are added to inputs
    if mod(length(inputs),2) ~= 0 %error if invalid quantity of function inputs
        error('Name-Pair method employed: Check input parameters for possible omition due to odd number of inputs received');
    end

    for kk = 1:2:length(inputs)
      eval(sprintf('variables.%s = inputs{kk+1};',lower(inputs{kk}))); %feed the vector into the variable
    end
end