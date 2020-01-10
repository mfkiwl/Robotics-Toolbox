close all
clear

load('path_3D_example.mat');
test_rloc = 2;
if test_rloc==1
    [quav,~,~,tq] = calctraj(rloc1,0.5*ones(size(rloc1(1,:))),0.1,2);
else
    [quav,~,~,tq] = calctraj(rloc2,0.5*ones(size(rloc2(1,:))),0.1,2);
end
quav = [quav,zeros(size(quav))];

mdl_quadrotor; qrsize = 1;

figure;
for i=1:length(obs)
   obs(i).plot(qobs(i,:),'workspace', [0 5 0 5 0 5],'facecolor','k','facealpha',0.5);
   hold on; 
end
h = qrplot(quav(1,:),qrsize,quadrotor);
plot3(quav(:,1),quav(:,2),quav(:,3),'r-','linewidth',2);
view(3); xlabel('x');ylabel('y');zlabel('z'); rotate3d on;
hold off


% write video
video_on = true;
if video_on
    respath = '/home/chu/Documents/MATLAB/Results/';
    videoname = [respath 'uav_3d_demo_v1.0'];
    writerObj = VideoWriter(videoname);
    open(writerObj);
end

tic;
playspeed = 2;
while toc<tq(end)/playspeed
    tnow = toc*playspeed;
    % choose via point in time 'tnow'
    q = interp1(tq,quav,tnow); 
    % update object
    qranimate(h,q,qrsize,quadrotor);
    drawnow
    if video_on
        frame = getframe;
        frame.cdata = imresize(frame.cdata,[480,640]);
        writeVideo(writerObj,frame);
    end
end
if video_on
    close(writerObj);
end