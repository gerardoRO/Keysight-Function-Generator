function Check_Alt_Inputs(allowed_inputs,inputs)
%This function checks that all the alternative inputs that are passed to
%the mother function are valid.
if isempty(inputs); return; end %no inputted values
if isstruct(inputs{1}) %if a structure is passed, check the fields of the structure
inputs = inputs{1};
new_fields = fieldnames(inputs);
for k = 1:length(new_fields)
  if ~ismember(new_fields{k},allowed_inputs) %if field is not allowed, throw error
    error('%s is not a valid field',new_fields{k})
  end
end

else
for kk = 1:2:length(inputs) %iterate through all the names of the pairs and check for validity
  if ~ismember(inputs{kk},allowed_inputs)
    error('%s is not a valid field',inputs{kk})
  end
end
end

