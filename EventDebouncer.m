classdef EventDebouncer < handle
    % EventDebouncer
    %
    % Very useful for limiting the number of times a callback is executed. For
    % example when listening to markedClean events on graphics objects.
    %
    % debounce = EventDebouncer(1); %Throttle to 1s
    % for i = 1:10 
    %    debounce(@() disp(i)); 
    %    pause(.2);
    % end
    %
    % Can debounce any number of function handles. debounce(@f1,@f2,@f3...);
    % Can be default constructed for 100ms.
    %
    % For an explination of what debounce vs. throttling does see:
    % https://redd.one/blog/debounce-vs-throttle
    %
    properties (SetObservable)
        delay (1,1) double; %Secconds
    end
    properties (Access=private)
        time (1,1) timer;
        functionList;
    end
    methods 
        function this = EventDebouncer(delay)
            arguments
                delay (1,1) double = .1;
            end
            this.delay = delay;
            this.time = timer(...
                "StartDelay", this.delay,...
                "TimerFcn", @(~,~) this.callFcns());
            
            this.addlistener("delay", "PostSet", @(~,~) this.updateTimerDelay());
        end
        function subsref(this,ref)
            for i = 1:numel(ref.subs)
                if ~isa(ref.subs{i}, "function_handle")
                    error("throttleCalls:MustBeFcnHandle", "Must call with a function handle");
                end
            end            
            if this.time.Running
                this.time.stop();
            end
            this.functionList = ref.subs;
            this.time.start();
        end
        function delete(this)
            this.time.stop();
            delete(this.time);
        end
    end
    methods (Access=private)
        function callFcns(this)
            for i = 1:numel(this.functionList)
                this.functionList{i}();
            end
        end
        function updateTimerDelay(this)
            this.time.StartDelay = this.delay;
        end
    end
end