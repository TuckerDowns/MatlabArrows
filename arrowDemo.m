st = rand(8,2);
ed = rand(8,2);

v = ed-st;

tiledlayout(1,2)
ax = nexttile;

quiver(ax, st(:,1), st(:,2), v(:,1), v(:,2))

ax = nexttile;
hold(ax,"on");
for i = 1:size(st,1)
    ar = arrow2D(st(i,:), ed(i,:),...
        "FaceColor", rand(1,3) * .7 + .2);
end

ar
