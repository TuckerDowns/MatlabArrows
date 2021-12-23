%  h = arrow2D(Start, Stop, "Prop1", value, ...) creates an arrow with the
%        given properties, using default values for any unspecified.
%        Returns a handle to the arrow object. Can be used to access and
%        set properties programatically. Only creates a single arrow, like
%        a graphics primitive.
%
%     0  *                    B    *               <-Stop
%        |                   /|\    \  L    
%        |                  /|||\    \  e   
%        |                 //|||\\    \  n  
%        |    r           ///|||\\\    \  g
%        |    a          ////|||\\\\    \  t  
%        # <- t         /////|||\\\\\    \  h 
%        |    i        ////  |||  \\\\    \  
%        |    o       ///    |||    \\\    \ 
%        |           //      |||      \\    \  
%     1  *           E       |||       C     * 
%                            |||  
%                            |||
%                            |||
%                            |||
%                            |A|                   <-Start
%                            
%                           |---| Width    
%   
%   Start        1x2 starting coordinate (data values)
%   Stop         1x2 stop coordinate, where the arrow "points to"
%                by default.
%   Width        The width of the arrow tail in pixels (default 2)
%   Length       The length of the arrow tail in pixels (default 24)
%   PointAngle   The angle of the arrow head (EBC) in degrees (default 36)
%   PointRatio   The depth of the arrow tail, value must be between
%                0 and 1. (default .7)
%
%   EdgeAlpha    The controls the transparency of the outline (default 1)
%   EdgeWidth    The width of the outline in pixels (default .5)
%   EdgeStyle    The linespec style for the outline (default "none")
%   EdgeColor    The color of the outline
%                                                             
%   FaceAlpha    The transparency of the arrow body (default 1)
%   FaceColor    The color of the arrow body.
%   Filled       logical value to control if the interior of the arrow is
%                shown
%   ArrowType    "start", "stop", "both" which sides have arrowheads.
%   Axis         Axis to draw arrow on
%
classdef arrow2D < handle
    properties (SetObservable)
        Start (1,2) double = [0 0]
        Stop (1,2) double = [1 1]
        Width (1,1) double = 1.5;
        Length (1,1) double = 24;
        PointAngle (1,1) double {mustBeInRange(PointAngle,0.0001,89.9999)} = 36;
        PointRatio (1,1) double {mustBeInRange(PointRatio,0,1)} = .7;
        
        EdgeAlpha = 1;
        EdgeWidth (1,1) double = .5;
        EdgeStyle = 'none';
        EdgeColor = 'k';
        
        FaceAlpha = 1;
        FaceColor = 'k';
        Filled = true;
        
        ArrowType (1,1) arrowType = "start";
    end
    properties (Access=private,Transient,NonCopyable)
        arrowPos;
        patchOrder;
        patchH;
        
        ax
        
        posListeners event.listener = event.listener.empty();
        selfListeners event.listener = event.listener.empty();        
    end
    properties (Access=private, Transient)
        debouncePos (1,1) EventDebouncer;
        debounceCol (1,1) EventDebouncer;
    end
    methods
        function this = arrow2D(Start, Stop, named)
            arguments
                Start (1,2) = [0 0]
                Stop  (1,2) = [1 1]
                named.Axis (1,1) matlab.graphics.axis.Axes = gca
                
                named.Width (1,1) double = 1.5;
                named.Length (1,1) double = 24;
                named.PointAngle (1,1) double {mustBeInRange(named.PointAngle,0.0001,89.9999)} = 36;
                named.PointRatio (1,1) double {mustBeInRange(named.PointRatio,0,1)} = .7;
                
                named.EdgeAlpha = 1;
                named.EdgeWidth (1,1) double = .5;
                named.EdgeStyle = 'none';
                named.EdgeColor = 'k';
                
                named.FaceAlpha = 1;
                named.FaceColor = 'k';
                named.Filled = true;
                
                named.ArrowType (1,1) arrowType = "start";
            end
            this.ax = named.Axis;
            
            this.Start = Start;
            this.Stop = Stop;
            
            for f = string(fields(named))'
                if strcmpi(f, "axis")
                    continue
                end
                this.(f) = named.(f);
            end
            
            prevHold = ishold(this.ax);
            if ~prevHold
                delete(this.ax.Children);
            end
            hold(this.ax, "on")
            
            this.debouncePos = EventDebouncer(.2);
            this.debounceCol = EventDebouncer;
            
            this.patchH = patch(this.ax,...
                "Faces", [1 2 1],...
                "Vertices", [0 0; 1 1]);

            this.setPositionObservers();
            this.setSelfObservers();
            this.update();
            if ~prevHold; hold(this.ax,'off'); end
        end
        function delete(this)
            delete(this.patchH);
            delete(this.debouncePos);
            delete(this.debounceCol);
        end
    end
    methods (Access=protected)
        function setPatchToPos(this)
            this.patchH.Faces = this.patchOrder;
            this.patchH.Vertices = this.arrowPos;
        end
        function updatePosition(this)
            this.debouncePos(@() this.calcArrowPos(), @() this.setPatchToPos());
        end
        function update(this)
            this.updatePosition();
            this.setColors();
        end
        function setColors(this)
            this.debounceCol(@f);
            function f()
                this.patchH.EdgeColor = this.EdgeColor;
                this.patchH.EdgeAlpha = this.EdgeAlpha;
                this.patchH.LineStyle = this.EdgeStyle;
                this.patchH.LineWidth = this.EdgeWidth;
                
                this.patchH.FaceAlpha = this.FaceAlpha;
                this.patchH.FaceColor = this.FaceColor;
                
                if ~this.Filled
                    this.patchH.FaceAlpha = 0;
                end
            end
        end
        
        function calcArrowPosBoth(this)
            % Convert data points to pixels
            [hCamera, aboveMatrix, hDataSpace, belowMatrix] =  matlab.graphics.internal.getSpatialTransforms(this.ax);
            tempVecs  = matlab.graphics.internal.transformDataToWorld(hDataSpace, belowMatrix, [this.Start; this.Stop]');
            pxArrowEnds = matlab.graphics.internal.transformWorldToViewer(hCamera, aboveMatrix, hDataSpace, belowMatrix, tempVecs)';
            
            %Build arrow with pixel coords
            v = pxArrowEnds(2,:) - pxArrowEnds(1,:); %Arrow as vector
            d = sum(v.^2).^.5; %Arrow Len
            
            tempPos = nan(10,2);

            % Top Half
            tempPos(10,:) = [0, d];
            
            rWingEnd(1) = sind(this.PointAngle/2) * this.Length;
            rWingEnd(2) = -sqrt(this.Length^2 - rWingEnd(1)^2);
            rWingEnd = (rWingEnd) + [0 d];
            
            tempPos(8,:) = rWingEnd;
            tempPos(9,:) = rWingEnd .* [-1 1];
            
            tempPos(7,:) = [-this.Width/2   rWingEnd(2) * this.PointRatio + (d - this.Width/2 * tand(90 - this.PointAngle/2)) * (1-this.PointRatio)];
            tempPos(6,:) = [+this.Width/2   rWingEnd(2) * this.PointRatio + (d - this.Width/2 * tand(90 - this.PointAngle/2)) * (1-this.PointRatio)];
            
            % Bottom Half
            tempPos(1,:) = [0 0];
            
            rWingEnd(2) = sind(90 - this.PointAngle/2) * this.Length;
            rWingEnd(1) = cosd(90 - this.PointAngle/2) * this.Length;
            
            tempPos(2,:) = rWingEnd;
            tempPos(3,:) = rWingEnd .* [-1 1];            
            
            tempPos(5,:) = [-this.Width/2   rWingEnd(2) * this.PointRatio + (this.Width/2 * tand(90 - this.PointAngle/2)) * (1-this.PointRatio)];
            tempPos(4,:) = [+this.Width/2   rWingEnd(2) * this.PointRatio + (this.Width/2 * tand(90 - this.PointAngle/2)) * (1-this.PointRatio)];
            
            %Affine Rotate into final position
            transform = eye(3);
            
            theta = atan2d(v(2), v(1)) - 90;
            transform(1,3) = pxArrowEnds(1,1);
            transform(2,3) = pxArrowEnds(1,2);
            
            transform([1 2],[1 2]) = [
                cosd(theta) -sind(theta)
                sind(theta) cosd(theta)];
            
            tempPos(:,3) = 1;
            tempPos = transform * tempPos';
            tempPos = tempPos([1 2],:)';
            
            
            tempVecs = matlab.graphics.internal.transformViewerToWorld(hCamera, aboveMatrix, hDataSpace, belowMatrix, tempPos');
            tempPos = matlab.graphics.internal.transformWorldToData(hDataSpace, belowMatrix, tempVecs);
            this.arrowPos = tempPos([1,2],:)';
            this.patchOrder = [4 6 8 10 9 7 5 3 1 2 4];
        end
        function calcArrowPos(this)
            if this.ArrowType == "both"
                this.calcArrowPosBoth();
                return;
            end
            
            % Convert data points to pixels
            [hCamera, aboveMatrix, hDataSpace, belowMatrix] =  matlab.graphics.internal.getSpatialTransforms(this.ax);
            tempVecs  = matlab.graphics.internal.transformDataToWorld(hDataSpace, belowMatrix, [this.Start; this.Stop]');
            pxArrowEnds = matlab.graphics.internal.transformWorldToViewer(hCamera, aboveMatrix, hDataSpace, belowMatrix, tempVecs)';
            
            %Build arrow with pixel coords
            v = pxArrowEnds(2,:) - pxArrowEnds(1,:); %Arrow as vector
            d = sum(v.^2).^.5; %Arrow Len
            
            tempPos = nan(7,2);
            
            tempPos([1 2], :) = [
                -this.Width/2, 0
                this.Width/2, 0];
            
            tempPos(7,:) = [0, d];
            
            rWingEnd(1) = sind(this.PointAngle/2) * this.Length;
            rWingEnd(2) = -sqrt(this.Length^2 - rWingEnd(1)^2);
            rWingEnd = (rWingEnd) + [0 d];
            
            tempPos(6,:) = rWingEnd;
            tempPos(5,:) = rWingEnd .* [-1 1];
            
            tempPos(3,:) = [-this.Width/2   rWingEnd(2) * this.PointRatio + (d - this.Width/2 * tand(90 - this.PointAngle/2)) * (1-this.PointRatio)];
            tempPos(4,:) = [+this.Width/2   rWingEnd(2) * this.PointRatio + (d - this.Width/2 * tand(90 - this.PointAngle/2)) * (1-this.PointRatio)];
            
            %Affine Rotate into final position
            transform = eye(3);
            
            if this.ArrowType == "stop"
                theta = atan2d(v(2), v(1)) - 90 + 180;
                transform(1,3) = pxArrowEnds(2,1);
                transform(2,3) = pxArrowEnds(2,2);
            elseif this.ArrowType == "start"
                theta = atan2d(v(2), v(1)) - 90;
                transform(1,3) = pxArrowEnds(1,1);
                transform(2,3) = pxArrowEnds(1,2);
            end
            
            transform([1 2],[1 2]) = [
                cosd(theta) -sind(theta)
                sind(theta) cosd(theta)];
            
            tempPos(:,3) = 1;
            tempPos = transform * tempPos';
            tempPos = tempPos([1 2],:)';
            
            
            tempVecs = matlab.graphics.internal.transformViewerToWorld(hCamera, aboveMatrix, hDataSpace, belowMatrix, tempPos');
            tempPos = matlab.graphics.internal.transformWorldToData(hDataSpace, belowMatrix, tempVecs);
            this.arrowPos = tempPos([1,2],:)';
            this.patchOrder = [4 2 1 3 5 7 6 4];
        end
        
        function setPositionObservers(this)
            if ~verLessThan('matlab', '9.10')
                this.posListeners(end+1) = this.ax.XAxis.addlistener("LimitsChanged", @(~,~) this.updatePosition());
                this.posListeners(end+1) = this.ax.YAxis.addlistener("LimitsChanged", @(~,~) this.updatePosition());
                this.posListeners(end+1) = this.ax.ZAxis.addlistener("LimitsChanged", @(~,~) this.updatePosition());
            else
                this.posListeners(end+1) = this.ax.addlistener("SizeChanged", @(~,~) this.updatePosition());
                this.posListeners(end+1) = this.ax.addlistener("MarkedClean", @(~,~) this.updatePosition());
            end
            this.posListeners(end+1) = this.patchH.addlistener("ObjectBeingDestroyed", @(~,~) this.clearListening());
        end
        function setSelfObservers(this)
            this.selfListeners(end+1) = this.addlistener("Start", "PostSet", @(~,~) this.updatePosition());
            this.selfListeners(end+1) = this.addlistener("Stop", "PostSet", @(~,~) this.updatePosition());
            this.selfListeners(end+1) = this.addlistener("Width", "PostSet", @(~,~) this.updatePosition());
            this.selfListeners(end+1) = this.addlistener("Length", "PostSet", @(~,~) this.updatePosition());
            this.selfListeners(end+1) = this.addlistener("PointAngle", "PostSet", @(~,~) this.updatePosition());
            this.selfListeners(end+1) = this.addlistener("PointRatio", "PostSet", @(~,~) this.updatePosition());
            this.selfListeners(end+1) = this.addlistener("ArrowType", "PostSet", @(~,~) this.updatePosition());
            
            this.selfListeners(end+1) = this.addlistener("EdgeAlpha", "PostSet", @(~,~) this.setColors());
            this.selfListeners(end+1) = this.addlistener("EdgeWidth", "PostSet", @(~,~) this.setColors());
            this.selfListeners(end+1) = this.addlistener("EdgeStyle", "PostSet", @(~,~) this.setColors());
            this.selfListeners(end+1) = this.addlistener("EdgeColor", "PostSet", @(~,~) this.setColors());
            
            this.selfListeners(end+1) = this.addlistener("FaceAlpha", "PostSet", @(~,~) this.setColors());
            this.selfListeners(end+1) = this.addlistener("FaceColor", "PostSet", @(~,~) this.setColors());
            this.selfListeners(end+1) = this.addlistener("Filled", "PostSet", @(~,~) this.setColors());
        end
        function clearListening(this)
            delete(this.selfListeners);
            delete(this.posListeners);            
            delete(this);
        end
    end
end
