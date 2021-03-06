% Investigation of the decay of the velocity boundary layer for flow over a
% porous bed.

close all
clearvars
clc

% create input structure
input_params = default_input_params('darcy_study', 1);

% modify structure as needed, or add additional problem-dependent params
n_layers = 30;
Lx = 1;
Ly = Lx*n_layers;
circles = false;

input_params.box_size = [Lx,Ly];
input_params.panels = 20;
input_params.plot_domain = 1;
input_params.pressure_drop_x = 0;
input_params.pressure_drop_y = 10;

% set up radii and centers, centers given as complex numbers (x+iy)
c = 0.3;% concentration
x_centers = zeros(n_layers,1);
y_centers = -n_layers/2*Lx:Lx:(n_layers-1)*Lx/2;
centers = x_centers(:) + 1i*(y_centers(:)+Lx/2);
input_params.centers = centers(1:end-1);

if circles
    radii = Lx*sqrt(c/pi);    
    input_params.radii = radii*ones(length(input_params.centers),1);
    
    problem_full = circles_periodic(input_params);
else
    %prescribe semi-major axis a
    input_params.a = 0.4*Lx*ones(length(input_params.centers),1);
    input_params.b = Lx^2*c./(pi * input_params.a);
    input_params.angles = 3*pi/12*ones(length(input_params.centers),1);
    
    problem_full = ellipses_periodic(input_params);
end

% solve the full problem
solution_full = solve_stokes(problem_full);

%% compute permeability for a single reference obstacle
input_params.box_size = [Lx,Lx];
input_params.centers = centers(1) + 1i*Lx/2;
input_params.plot_domain = 0;

if circles
    input_params.radii = input_params.radii(1);
    
    problem = circles_periodic(input_params);
else
    %prescribe semi-major axis a
    input_params.a = input_params.a(1);
    input_params.b = input_params.b(1);
    input_params.angles = input_params.angles(1);
    
    problem = ellipses_periodic(input_params);
end

K = zeros(2,2);

% solve for K_{11} and K_{12} by imposing pressure gradient in x direction
problem.pressure_gradient_x = 1/Lx;
problem.pressure_gradient_y = 0;

% solve the problem
solution_tmp = solve_stokes(problem);

% average velocity is computed already!
K(:,1) = solution_tmp.u_avg;

% solve for K_{21} and K_{22} by imposing pressure gradient in y direction
problem.pressure_gradient_x = 0;
problem.pressure_gradient_y = 1/Lx;

% solve the problem
solution_tmp = solve_stokes(problem);

K(:,2) = solution_tmp.u_avg;

%% compute averages in each layer
[u_avg, p_avg, p_grad_avg] = compute_cell_averages(solution_full, 1, Ly);
u_avg = u_avg(:,1) + 1i*u_avg(:,2);

% p_avg(1:end/2) = p_avg(1:end/2);
% p_grad_avg(1:end/2,:) = p_grad_avg(1:end/2,:);

%% plot Stokes solution
Nx = 50;
Ny = Nx*n_layers;
x = linspace(-Lx/2, Lx/2, Nx);
y = linspace(n_layers/2, -n_layers/2, Ny);
[X, Y] = meshgrid(x, y);

[U, V, X, Y] = evaluate_velocity(solution_full, X, Y);
P = evaluate_pressure(solution_full, X, Y);
[Px, Py] = evaluate_pressure_gradient(solution_full, X, Y);

Xstokes = X;
Ystokes = Y;

figure()
subplot(1,5,1);
contourf(Xstokes, Ystokes, U);
axis equal
title('U');
colorbar;

subplot(1,5,2);
contourf(Xstokes, Ystokes, V);
axis equal
title('V');
colorbar;

subplot(1,5,3);
contourf(Xstokes, Ystokes, P);
axis equal
title('P');
colorbar;

subplot(1,5,4);
contourf(Xstokes, Ystokes, Px);
axis equal
title('P_x');
colorbar;

subplot(1,5,5);
contourf(Xstokes, Ystokes, Py);
axis equal
title('P_y');
colorbar;

%% plot homogenized solution

Uavg = zeros(size(U));
Vavg = zeros(size(V));
Pavg = zeros(size(P));
Pxavg = zeros(size(Px));
Pyavg = zeros(size(Py));

for i = 1:length(u_avg)
    indices_tmp = (i-1)*Nx+1:i*Nx;
    
    Uavg(indices_tmp,:) = real(u_avg(end-i+1));
    Vavg(indices_tmp,:) = imag(u_avg(end-i+1));
    Pavg(indices_tmp,:) = p_avg(end-i+1);
    Pxavg(indices_tmp,:) = p_grad_avg(end-i+1,1);
    Pyavg(indices_tmp,:) = p_grad_avg(end-i+1,2);
end

Xhomogenized = X;
Yhomogenized = Y;

figure()

subplot(1,5,1);
contourf(Xhomogenized, Yhomogenized, Uavg);
axis equal
title('U^d');
colorbar;

subplot(1,5,2);
contourf(Xhomogenized, Yhomogenized, Vavg);
axis equal
title('V^d');
colorbar;

subplot(1,5,3);
contourf(Xhomogenized, Yhomogenized, Pavg);
axis equal
title('P^d');
colorbar;

subplot(1,5,4);
contourf(Xhomogenized, Yhomogenized, Pxavg);
axis equal
title('P_x^d');
colorbar;

subplot(1,5,5);
contourf(Xhomogenized, Yhomogenized, Pyavg);
axis equal
title('P_y^d');
colorbar;

%% compute expected Darcy velocity 
u_expected = zeros(size(u_avg,1),2);
p_expected = zeros(size(u_avg,1),1);
px_expected = zeros(size(u_avg,1),1);
py_expected = zeros(size(u_avg,1),1);

for i = 1:n_layers
   %u_expected(i,:) = 2*(K*[problem_full.pressure_gradient_x;problem_full.pressure_gradient_y])';
    u_expected(i,:) = (K*p_grad_avg(i,:)')';
    p_expected(i) = nan;
    px_expected(i) = nan;
    py_expected(i) = nan;
end

% expected velocity above interface is the velocity evaluated at the cell
% center
% for i = 1:n_layers
%     [utmp, vtmp] = evaluate_velocity(solution_full, 0, (i-1)+0.5);
%     [pxtmp,pytmp] = evaluate_pressure_gradient(solution_full, 0, (i-1)+0.5);
%     ptmp = evaluate_pressure(solution_full, 0, (i-1)+0.5);
%     
%     u_expected(n_layers + i,1) = utmp;
%     u_expected(n_layers + i,2) = vtmp;
%     p_expected(n_layers + i) = ptmp;
%     px_expected(n_layers +i) = pxtmp;
%     py_expected(n_layers +i) = pytmp;
% end

u_expected = u_expected(:,1) + 1i*u_expected(:,2);

% plot difference
figure;

fontsize = 14;

subplot(1,7,1);
plot(problem_full.domain.z(1:end-1), 'b');
hold on
plot(problem_full.domain.z(1:end-1) + Lx, 'b');
plot(problem_full.domain.z(1:end-1) - Lx, 'b');
axis equal;
grid on
set(gca, 'xtick', [-3*Lx/2, -Lx/2, Lx/2, 3*Lx/2]);
set(gca, 'ytick', -n_layers*Lx : Lx: n_layers*Lx);
ylim([-n_layers/2*Lx, n_layers/2*Lx]);
set(gca,'Fontsize',fontsize);

subplot(1,7,2)
plot(log10(abs((u_expected - u_avg)./u_expected)), 1:Ly);
xlabel('u_{darcy} - u_{avg}');
ylabel('layer');
set(gca,'Fontsize',fontsize);
 
subplot(1,7,3)
plot(real(u_avg), 1:Ly);
hold on
plot(real(u_expected), 1:Ly);
xlabel('u_{avg}: x');
ylabel('layer');
set(gca,'Fontsize',fontsize);

subplot(1,7,4)
plot(imag(u_avg),  1:Ly);
hold on
plot(imag(u_expected), 1:Ly);
xlabel('u_{avg}: y');
ylabel('layer');
set(gca,'Fontsize',fontsize);

subplot(1,7,5)
plot(p_avg, 1:Ly);
hold on
plot(p_expected, 1:Ly);
xlabel('p^d');
ylabel('layer');
set(gca,'Fontsize',fontsize);

subplot(1,7,6)
plot(p_grad_avg(:,1), 1:Ly);
hold on
plot(px_expected, 1:Ly);
xlabel('p_x^d');
ylabel('layer');
set(gca,'Fontsize',fontsize);

subplot(1,7,7)
plot(p_grad_avg(:,2), 1:Ly);
hold on
plot(py_expected, 1:Ly);
xlabel('p_y^d');
ylabel('layer');
set(gca,'Fontsize',fontsize);
