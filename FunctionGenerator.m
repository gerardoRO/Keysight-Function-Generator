%%% Class definition for Function Generator Keysight 33500B Series
%%% Created by Gerardo Rodriguez Orellana 2020

% Requires USB connection to computer
% Requires Measurement Toolbox from Matlab

% Purpose is to allow fast and efficient communication between function
% generator and Matlab for the delivery of custom ultrasound waveforms. It
% allows pulsed ultrasound to be delivered at different frequencies, PRFs,
% duty cycles as well as the loading and stimulation of custom designed
% waveforms. Look under each function to understand its function.

% If need to modify commands, look for SCPI reference for 33500B
% Comments/questions/suggestions to rodr0283@umn.edu

classdef FunctionGenerator
    properties
        wp;
        sampling_rate = 1000000; %Hz
        instr;
        logID;
    end
    
    methods
        function obj = FunctionGenerator(varargin)
            FIELDS = {'wp'};
            VALUES = {fileparts(mfilename('fullpath'))}; LOCALDEF=[FIELDS;VALUES];
            vars = struct(LOCALDEF{:}); vars = vararginReader(varargin,vars);
            obj.wp = vars.wp;
            try
                devID = instrhwinfo('visa','ni');
                eval(sprintf('obj.instr=%s',devID.ObjectConstructorName{1})) %create instrument ID
                fopen(obj.instr);
                obj.instr.EOSMode = 'read&write'; %to write multiple commands per fprintf
                
                obj.Reset()
                obj.logID = fopen([vars.wp '\Agilent33500b_log'],'w');
                fprintf(obj.logID,'Succcessful connection\n');
                fprintf(obj.instr,'*IDN?');
                fprintf(obj.logID,fscanf(obj.instr));
            catch EXCEPTION                   
                error('Could not connect to Function Generator')
            end
        end
        
        function Close(obj)
            %%% Close and delete function generator object.%%%
            fclose(obj.instr); fclose(obj.logID); delete(obj.instr);
        end
        
        function Go(obj,varargin)
            %%% Abilitate both channels for stimulation.%%%
            %Params - chan (optional)
            FIELDS = {'chan'}; VALUES = {[1,2]}; LOCALDEF = [FIELDS;VALUES];
            vars = struct(LOCALDEF{:}); vars = vararginReader(varargin,vars);
            Check_Alt_Inputs(FIELDS,varargin);
            
            if length(vars.chan) == 2
                fprintf(obj.instr,'OUTP1 ON; OUTP2 ON');
            else
                fprintf(obj.instr,sprintf('OUT%i ON',vars.chan));
            end
            
            %obj.SendTrigger();
            if Errors(obj); disp('Error: Check Agilent Log'); end
        end
        
        function Stop(obj,varargin)
        %%% Disabilitate both channels.%%%
            %Params - chan (optional)
            FIELDS = {'chan'}; VALUES = {[1,2]}; LOCALDEF = [FIELDS;VALUES];
            vars = struct(LOCALDEF{:}); vars = vararginReader(varargin,vars);
            Check_Alt_Inputs(FIELDS,varargin);
            
            if length(vars.chan) == 2
                fprintf(obj.instr,'OUTP1 OFF; OUTP2 OFF');
            else
                fprintf(obj.instr,sprintf('OUT%i ON',vars.chan));
            end
            
            obj.SendTrigger();
            if Errors(obj); disp('Error: Check Agilent Log'); end
        end
        
        function Reset(obj)
            fprintf(obj.instr,'SOUR1:APPLY:SIN 1MHz,0.1,0');
            fprintf(obj.instr,'SOUR2:APPLY:SIN 1MHz,0.1,0');
            fprintf(obj.instr,'OUTP1 OFF; OUTP2 OFF'); %set both channels to no output
            
            ClearMemory(obj);
            if Errors(obj); disp('Error: Check Agilent Log'); end
        end
        
        function error_found = Errors(obj)
            %%% Read all errors in the queue. %%%
            fprintf(obj.instr,'SYST:ERR?');
            err = fscanf(obj.instr);
            
            if contains(string(err),'No error')
                error_found = 0;
            else
                error_found = 1;
                
                fprintf(obj.logID,['Errors method: ' err]); %write all errors to log
                while ~contains(string(err),'No error')
                    fprintf(obj.instr,'SYST:ERR?');
                    err = fscanf(obj.instr);
                end
            end
        end
        
        function SendTrigger(obj)
          %Send BUS Trigger
            fprintf(obj.instr,'*TRG');
            ConfigureTrigger(obj,'source','BUS','chan',2);
            if Errors(obj); disp('Error: Check Agilent Log'); end
        end
        
        function ResetBuffer(obj,buffersize,input_output)
            %%Change buffer size for allowing writing/reading large text.
            fclose(obj.instr);
            if strcmp(input_output,'output')
                obj.instr.OutputBufferSize = buffersize;
            elseif strcmp(input_output,'input')
                obj.instr.InputBufferSize = buffersize;
            end
            fopen(obj.instr);
        end
        
        function ClearMemory(obj,varargin)
            %%% Clear volatile memory. %%%
            %Params: chan (optional)
            FIELDS = {'chan'}; VALUES = {1}; LOCALDEF = [FIELDS;VALUES];
            vars = struct(LOCALDEF{:}); vars = vararginReader(varargin,vars);
            Check_Alt_Inputs(FIELDS,varargin);
            
            fprintf(obj.instr,sprintf('OUTP%i OFF',vars.chan));
            fprintf(obj.instr,sprintf('SOUR%i:DATA:VOL:CLE',vars.chan));
            fprintf(obj.instr,sprintf('OUTP%i OFF',vars.chan));
            
            if Errors(obj); disp('Error: Check Agilent Log'); end
        end
        
        function is_inmem = CheckMemory(obj,file)
            %%% Check if file is in the volatile memory.%%%
            fprintf(obj.instr,'DATA:VOL:CAT?');
            
            is_inmem = contains(fscanf(obj.instr),file);
        end
        
        function waveforms =WaveformsAvailable(obj,folder)
            %%% Return available waveforms found in the specified folder.%%          
            ResetBuffer(obj,4000,'input'); %increase buffer size to read successully
            fprintf(obj.instr,sprintf('MMEM:CAT:DATA:ARB? "%s"',folder));
            
            fullstring = fscanf(obj.instr);
            ResetBuffer(obj,512,'input');
            
            waveforms = extractBetween(fullstring,',"','.barb');
            if Errors(obj); disp('Error: Check Agilent Log'); end
        end
        
        function ChangeVoltage(obj,channel,new_voltage)
            %%% Change voltage for channel to new_voltage
            if new_voltage > .95
                disp('Voltage too high!');
                inp = input('Continue? y | [n]','s');
                if ~strcmp(inp,'y'); return; end
            end
            
            fprintf(obj.instr,'OUTP1 OFF; OUTP2 OFF'); %set both channels to no output
            command = sprintf('SOUR%i:VOLT +%i',channel,new_voltage);
            fprintf(obj.instr,command);
        end
        
        function ConfigurePulse(obj,varargin)
            %%% Set up ChX to output a pulse. %%%
            % Params - duty_cycle , duration, repetition_frequency (2 out 3
            % necessary), 'chan' (optional)
            FIELDS={'duty_cycle','duration','repetition_frequency','chan','amplitude'};
            VALUES={0,.01,1,2,.6}; LOCALDEF=[FIELDS;VALUES];
            vars = struct(LOCALDEF{:}); vars = vararginReader(varargin,vars);
            Check_Alt_Inputs(FIELDS,varargin);
            
            %need minimum of 2 out of 3 to calculate necessary parameters
            if nnz([vars.duty_cycle,vars.duration,vars.repetition_frequency]) < 2
                throw('Need 2 out of the following: duty cycle, duration, or repetition frequency')
            end
            
            %Calculate PRF or Duration (PW) depending on inputted
            %parameters
            if ~vars.repetition_frequency
                vars.repetition_frequency = vars.duration*100 / vars.duty_cycle;
            elseif ~vars.duration
                vars.duration = vars.repetition_frequency * vars.duty_cycle / 100;
            end
            
            command = sprintf([
                'SOUR%i:APPLY:PULSE %2dhz\n'...
                'SOUR%i:FUNC:PULSE:WIDTH %2d\n'],...
                vars.chan,vars.repetition_frequency,...
                vars.chan,vars.duration);
            fprintf(obj.instr,command);
            fprintf(obj.instr,sprintf('OUTP%i OFF',vars.chan));
            fprintf(obj.instr,sprintf('SOUR%i:VOLT +%i',vars.chan,vars.amplitude));

            if Errors(obj); disp('Error: Check Agilent Log'); end
        end  
        
        function ConfigureModulation(obj,varargin)
            %%% Configure a channel to perform pulse modulation of the other channel.%%%
            % Params - duty_cycle , duration, repetition_frequency (2 out 3
            % necessary), 'pulse_chan' (optional)
            FIELDS={'chan'};
            VALUES={2}; LOCALDEF=[FIELDS;VALUES];
            vars = struct(LOCALDEF{:}); vars = vararginReader(varargin,vars);
            Check_Alt_Inputs(FIELDS,varargin);
            
            %configure output channel depending on modulation channel
            if vars.chan == 1; vars.out_chan = 2; else; vars.out_chan = 1; end
            
            command = sprintf([
                'SOUR%i:AM:SOUR CH%i\n'...
                'SOUR%i:AM:STATE 1'],vars.out_chan,vars.chan,vars.out_chan);
            fprintf(obj.instr,command);
            fprintf(obj.instr,sprintf('OUTP%i OFF',vars.chan));
            if Errors(obj); disp('Error: Check Agilent Log'); end
        end
        
        function ConfigureTrigger(obj,varargin)
            %%%Configure channel to output one cycle per trigger.%%%
            %Params - source (optional) chan (optional) trig_timer
            %(optional)
            FIELDS = {'source','chan','trig_timer'}; VALUES = {'EXT',[1,2],1}; LOCALDEF = [FIELDS;VALUES];
            vars = struct(LOCALDEF{:}); vars = vararginReader(varargin,vars);
            Check_Alt_Inputs(FIELDS,varargin);

            for eachan = vars.chan
                command = sprintf(['SOUR%i:BURST:MODE TRIG\n'...
                                   'TRIG%i:SOUR %s\n'...
                                   'SOUR%i:BURST:NCYC 1\n'...
                                   'SOUR%i:BURST:STATE 1\n'],eachan,eachan,vars.source,eachan,eachan);
                fprintf(obj.instr,command);
                
                
                if strcmp(vars.source,'TIM')
                    fprintf(obj.instr,sprintf('TRIG%i:TIM %2d',eachan,vars.trig_timer));
                end
            end
            
            if Errors(obj); disp('Error: Check Agilent Log'); end
        end
        
        function LoadWaveform(obj,wav_name,varargin)
            %%% Load wav_name into volatile memory. Default in USB. %%%
            %Params - wav_name , path (optional),chan(optional),samp_rate
            FIELDS = {'path','chan','samp_rate'}; VALUES = {'USB:\',1,obj.sampling_rate}; LOCALDEF = [FIELDS;VALUES];
            vars = struct(LOCALDEF{:}); vars = vararginReader(varargin,vars);
            Check_Alt_Inputs(FIELDS,varargin);
            
            
            command = sprintf(['SOUR%i:VOLT:UNIT VPP\n'...
                'SOUR%i:FREQ:MODE CW\n'...
                'SOUR%i:FUNC ARB\n'...
                'MMEM:LOAD:DATA%i "%s"\n'...
                'SOUR%i:FUNC:ARB "%s"\n'...
                'SOUR%i:FUNC:ARB:SRAT %i\n'...
                'SOUR%i:VOLT 0.01 VPP\n'...
                'SOUR%i:VOLT:OFFS 0.00'],vars.chan,vars.chan,vars.chan,vars.chan,[vars.path wav_name],vars.chan,[vars.path wav_name],vars.chan,vars.samp_rate,vars.chan,vars.chan);
            fprintf(obj.instr,command);
            
            if Errors(obj); fprintf('Error: Check Agilent Log --- waveform %s\n',wav_name); end
        end
        
        function LoadState(obj,state,varargin)
            %%% Load state. Default in USB. %%%
            %Params - path (optional),chan(optional),samp_rate
            FIELDS = {'path'}; VALUES = {'USB:\STATES\'}; LOCALDEF = [FIELDS;VALUES];
            vars = struct(LOCALDEF{:}); vars = vararginReader(varargin,vars);
            Check_Alt_Inputs(FIELDS,varargin);
            
            command = sprintf('MMEM:LOAD:STAT "%s"',[vars.path state ]);
            fprintf(obj.instr,command);
            
            if Errors(obj); disp('Error: Check Agilent Log'); end
        end
        
        function UploadWaveform(obj,waveform,wave_name,sampling_rate,varargin)
            %%% Create and upload "name" "waveform" to the specific channel. %%%
            %Params - waveform, wave_name, sampling_rate, chan (optional)
            FIELDS = {'chan','path'}; VALUES = {1,'USB:\'}; LOCALDEF = [FIELDS;VALUES];
            vars = struct(LOCALDEF{:}); vars = vararginReader(varargin,vars);
            Check_Alt_Inputs(FIELDS,varargin);
            
            scale = .5*(max(waveform)- min(waveform));
            offset = min(waveform) + scale; %rescale waveform to -1 to 1
            
            waveform = int16(((waveform-offset)/scale) * 32767); %scale wav from -32767 to 32767 as int16
            wv_str = '';
            for k=waveform; wv_str = wv_str + string(k) + ','; end %change wave to string
            wv_str = char(wv_str); wv_str = wv_str(1:end-1); %cast as char to remove end and iD length for buffer
            
            ResetBuffer(obj,length(wv_str) + 500,'output'); %reset buffer to write waveform
            
            wv_str = string(wv_str); %recast as string to print all in one %s
            command = sprintf(['SOUR%i:DATA:ARB:DAC %s,%s\n'...
                'SOUR%i:FUNC:ARB %s\n'...
                'SOUR%i:APPLY:ARB %i,0.1,0'],vars.chan,wave_name,wv_str,vars.chan,wave_name,vars.chan,sampling_rate);
            fprintf(obj.instr,command);
            
            command = sprintf('MMEM:STORE:DATA ''%s%s.barb''',vars.path,wave_name); %save waveform to mass storage
            fprintf(obj.instr,command);
            
            ResetBuffer(obj,512,'output'); %set buffer to default for sped up writing
            if Errors(obj); disp('Error: Check Agilent Log'); end
        end
        
        function crest_factor = ReturnCrestFactor(obj,waveform,varargin)
            %%% Return the Crest Factor of the Waveform specified. %%%
            FIELDS={'path'};VALUES={'USB:\'}; LOCALDEF=[FIELDS;VALUES];
            vars = struct(LOCALDEF{:}); vars = vararginReader(varargin,vars);
            
            if CheckMemory(obj,[vars.path waveform])
                fprintf(obj.instr,sprintf('DATA:ATTR:CFAC? "%s%s"',vars.path,waveform));
                crest_factor = double(string(fscanf(obj.instr))); %return crestfactor
            else
                warning('Waveform not in volatile memory; load first')
                crest_factor = 0;
            end
        end
        
        function p2pval = ReturnPeaktoPeak(obj,waveform,varargin)
            %%% Return the Crest Factor of the Waveform specified. %%%
            FIELDS={'path'};VALUES={'USB:\'}; LOCALDEF=[FIELDS;VALUES];
            vars = struct(LOCALDEF{:}); vars = vararginReader(varargin,vars);
            
            if CheckMemory(obj,[vars.path waveform])
                fprintf(obj.instr,sprintf('DATA:ATTR:PTP? "%s%s"',vars.path,waveform));
                p2pval = double(string(fscanf(obj.instr))); %return crestfactor
            else
                warning('Waveform not in volatile memory; load first')
                p2pval = 0;
            end
        end
 
    end
end


