% - Lidar 2D/3D Model class (SE3, rpy, stdDH)
% (last mod.: 02-04-2020, Author: Chu Wu)
% Requires rvc & rte https://github.com/star2dust/Robotics-Toolbox
% Properties:
% - name: str (lidar*)
% - radius: detect radius (1x1)
% - alim: limit of angle (1x2)
% - hlim: limit of height (1x2)
% Methods:
% - Lidar: construction (arg: radius)
% (opt: name, alim, hlim, dens)
% - plot (arg: q (1x3))
% (opt: workspace, dim, licolor, lithick)
% - animate (arg: q (1x3))
% Methods (Static): (for cylinder Lidar)
classdef Lidar < handle
    properties
        name
        radius
        dens
        alim
        hlim
        xdata
        ydata
        zdata
    end
    
    methods
        function obj = Lidar(varargin)
            % L.Lidar  Create Lidar object
            
            % opt statement
            opt.name = 'lidar';
            opt.alim = [-pi/2,pi/2];
            opt.hlim = [0,0.5];
            opt.dens = 30;
            % opt parse: only stated fields are chosen to opt, otherwise to arg
            [opt,arg] = tb_optparse(opt, varargin);
            % check validity
            if length(arg)==1
                radius = arg{1}(:)';
            else
                error('unknown argument')
            end
            % struct
            obj.name = opt.name;
            obj.alim = opt.alim;
            obj.hlim = opt.hlim;
            obj.dens = opt.dens;
            obj.radius = radius;
            [obj.xdata,obj.ydata,obj.zdata] = Lidar.getData(obj.radius,obj.dens,obj.alim,obj.hlim);
        end
        
        function h = plot(obj,varargin)
            % L.plot  Plot Lidar object
            
            % opt statement
            opt.workspace = [];
            opt.dim = 3;
            opt.detect = true;
            opt.licolor = 'g';
            opt.lithick = 0.5;
            opt.decolor = 'r';
            opt.dethick = 3;
            % opt parse: only stated fields are chosen to opt, otherwise to arg
            [opt,arg] = tb_optparse(opt, varargin);
            % argument parse
            if length(arg)==1
                % get pose
                q = arg{1}(:)';
            else
                error('unknown arguments');
            end
            if strcmp(get(gca,'Tag'), 'RTB.plot')
                % this axis is an RTB plot window
                rhandles = findobj('Tag', obj.name);
                if isempty(rhandles)
                    % this robot doesnt exist here, create it or add it
                    if ishold
                        % hold is on, add the robot, don't change the floor
                        h = createLidar(obj, q, opt);
                        % tag one of the graphical handles with the robot name and hang
                        % the handle structure off it
                        %                 set(handle.joint(1), 'Tag', robot.name);
                        %                 set(handle.joint(1), 'UserData', handle);
                    else
                        % create the robot
                        newplot();
                        h = createLidar(obj, q, opt);
                        set(gca, 'Tag', 'RTB.plot');
                    end
                end
            else
                % this axis never had a robot drawn in it before, let's use it
                h = createLidar(obj, q, opt);
                set(gca, 'Tag', 'RTB.plot');
                set(gcf, 'Units', 'Normalized');
                %         pf = get(gcf, 'Position');
                %         if strcmp( get(gcf, 'WindowStyle'), 'docked') == 0
                %             set(gcf, 'Position', [0.1 1-pf(4) pf(3) pf(4)]);
                %         end
            end
            view(opt.dim); grid on; rotate3d on
            obj.animate(q, h.group);
        end
        
        function animate(obj, q, handles)
            % L.animate  Animate Lidar object
            
            if nargin < 3
                handles = findobj('Tag', obj.name);
            end
            % animate
            if handles.UserData
                Vdc = obj.detect(q);
            end
            for i=1:length(handles.Children) % draw frame first otherwise there will be delay
                if strcmp(get(handles.Children(i),'Tag'), [obj.name '-lidar'])
                    VF0 = handles.Children(i).UserData;
                    if length(VF0) == 1
                        p_fv = h2e(SE3.qrpy(q).T*e2h(VF0{1}'));
                        set(handles.Children(i), 'XData', p_fv(1,:),'YData', p_fv(2,:),'ZData', p_fv(3,:));
                    else
                        V = h2e(SE3.qrpy(q).T*e2h(VF0{1}'))';
                        set(handles.Children(i), 'vertices', V,'faces', VF0{2});
                    end
                end
                if handles.UserData
                    tag = get(handles.Children(i),'Tag');
                    if strcmp(tag(1:end-1), [obj.name '-detect'])
                        j = ceil(str2double(tag(end)));
                        if isempty(Vdc{j})
                            set(handles.Children(i),'Visible', 'off');
                        else
                            set(handles.Children(i),'XData',Vdc{j}(:,1), 'YData',...
                                Vdc{j}(:,2), 'ZData', ones(size(Vdc{j}(:,1)))*obj.hlim(2),'Visible', 'on');
                        end
                    end
                end
            end
        end
        
        function Vdc = detect(obj, q)
            load('map.mat','map_original');
            X = obj.xdata; Y = obj.ydata; Voc = map_original.Voc;
            Vd0 = [X(1,:);Y(1,:)]';
            Vd = [q(1:2);h2e(SE2(q).T*e2h(Vd0'))';q(1:2)];
            Vdc = cell(size(Voc));
            for i=1:length(Voc)
%                 plot(Voc{i}(:,1),Voc{i}(:,2),'b','LineWidth',5);
                Vdc{i} = Lidar.polyintersect2(Vd,Voc{i});
%                 if ~isempty(Vdc{i})
%                     plot(Vdc{i}(:,1),Vdc{i}(:,2),'r','LineWidth',5);
%                 end
            end
        end
    end
    methods (Access = protected)
        function h = createLidar(obj, q, opt)
            % create an axis
            ish = ishold();
            if ~ishold
                % if hold is off, set the axis dimensions
                if ~isempty(opt.workspace)
                    axis(opt.workspace);
                end
                hold on
            end
            
            group = hggroup('Tag', obj.name);
            group.UserData = opt.detect;
            h.group = group;
            
            % get X,Y,Z data
            q = SE3.qrpy(q).toqrpy;
            X = obj.xdata; Y = obj.ydata; Z = obj.zdata;
            if opt.dim == 2
                V0 = [X(1,:);Y(1,:);Z(1,:)]';
                p_fv = h2e(SE3.qrpy(q).T*e2h(V0'));
                h.lidar = line(p_fv(1,:),p_fv(2,:),p_fv(3,:),'Color',opt.licolor, 'LineWidth', opt.lithick, 'parent', group);
                h.lidar.UserData = {V0};
            else
                [F0,V0]= surf2patch(X,Y,Z);
                V = h2e(SE3.qrpy(q).T*e2h(V0'))';
                h.lidar = patch('vertices',V, 'faces', F0, 'facecolor',...
                    opt.licolor, 'facealpha', opt.lithick, 'edgecolor',...
                    opt.licolor, 'edgealpha', opt.lithick, 'parent', group);
                h.lidar.UserData = {V0,F0};
            end
            set(h.lidar,'Tag', [obj.name '-lidar']);
            
            if opt.detect
                Vdc = obj.detect(q);
                for i=1:length(Vdc)
                    if isempty(Vdc{i})
                        h.detect(i) = line('Color', opt.decolor, 'LineWidth', opt.dethick, 'Visible', 'off', 'parent', group);
                    else
                        h.detect(i) = line(Vdc{i}(:,1), Vdc{i}(:,2), ones(size(Vdc{i}(:,1)))*obj.hlim(2), 'Color',...
                            opt.decolor, 'LineWidth', opt.dethick, 'parent', group);
                    end
                    set(h.detect(i),'Tag', [obj.name '-detect' num2str(i)]);
                end
            end
            
            % restore hold setting
            if ~ish
                hold off
            end
        end
    end
    
    methods (Static)
        function [X,Y,Z] = getData(radius,num,alim,hlim)
            [X,Y,~] = cylinder(radius,num);
            X = X(:,[num/2+1:num,1:num/2,num/2+1]);
            Y = Y(:,[num/2+1:num,1:num/2,num/2+1]);
            Z = [ones(1,num+1)*hlim(1);ones(1,num+1)*hlim(2)];
            I = cart2pol(X(1,:),Y(1,:))-alim(1)>0&cart2pol(X(1,:),Y(1,:))-alim(2)<0; % [-pi,pi]
            X = X(:,I); Y = Y(:,I); Z = Z(:,I);
        end
        
        function V3 = polyintersect2(V1,V2)
            poly1_x = V1(:,1); poly1_y = V1(:,2);
            poly2_x = V2(:,1); poly2_y = V2(:,2);
            [ints_x, ints_y] = polygon_intersect(poly1_x, poly1_y, poly2_x, poly2_y);
            V3 = [ints_x(:),ints_y(:)];
        end
    end
end