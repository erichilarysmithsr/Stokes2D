function [U1c, U2c, X, Y, U1, U2] = evaluate_velocity(solution, varargin)
%EVALUTATE_VELOCITY evaluates the velocity on a regular grid over the 
%reference cell. Uses the stresslet identity to identify points inside the
%domain.
%
% inputs:
% -solution: structure containing the following fields
%   -domain: a domain structure containing geometry information
%   -q : density function, vector of size #npts by 2
%   -eta: factor in front of SLP in combined-layer formulation
% -N: number of points in each direction

disp('Evaluating velocity...');

domain = solution.problem.domain;
if solution.problem.periodic
    Lx = domain.Lx;
    Ly = domain.Ly;
end

xsrc = real(solution.problem.domain.z);
ysrc = imag(solution.problem.domain.z);
n1 = real(-1i*solution.problem.domain.zp)./abs(solution.problem.domain.zp);
n2 = imag(-1i*solution.problem.domain.zp)./abs(solution.problem.domain.zp);
weights = solution.problem.domain.wazp;

if nargin == 2 % N specified, evaluate on regular grid
    N = varargin{1};
    x = linspace(min(xsrc), max(xsrc), N);
    y = linspace(min(ysrc), max(ysrc), N);
    
    [X,Y] = meshgrid(x,y);
else % target points are specified
    X = varargin{1};
    Y = varargin{2};
end

if solution.problem.periodic
    [uslp1, uslp2] = StokesSLP_ewald_2p(xsrc, ysrc, X(:), Y(:),...
        solution.q(:,1).*weights, solution.q(:,2).*weights, Lx, Ly,...
        'verbose', 1);
    
    [udlp1, udlp2] = StokesDLP_ewald_2p(xsrc, ysrc, X(:), Y(:), n1, n2,...
        solution.q(:,1).*weights, solution.q(:,2).*weights, Lx, Ly,...
        'verbose', 1);
    
    uslp = uslp1 + 1i*uslp2;
    udlp = udlp1 + 1i*udlp2;
    
    disp('Beginning special quadrature...');
    
    % correct using special quadrature
    [uslp_corrected,~] = mex_SQ_slp(X(:)+1i*Y(:), domain.z, domain.zp,...
        domain.quad_weights, domain.panel_breaks, domain.wazp, domain.z32,...
        domain.zp32, domain.quad_weights32, domain.wazp32, ...
        solution.q(:,1)+1i*solution.q(:,2),...
        uslp,domain.mean_panel_length,domain.extra.gridSolidmat, ...
        domain.extra.Nrows,domain.extra.Ncols,domain.extra.panels2wall,...
        domain.reference_cell);
    
    [udlp_corrected,~] = mex_SQ_dlp(X(:)+1i*Y(:), domain.z, domain.zp,...
        domain.quad_weights, domain.panel_breaks, domain.wazp, domain.z32,...
        domain.zp32, domain.quad_weights32, domain.wazp32,...
        solution.q(:,1)+1i*solution.q(:,2),...
        udlp,domain.mean_panel_length,domain.extra.gridSolidmat, ...
        domain.extra.Nrows,domain.extra.Ncols,domain.extra.panels2wall,...
        domain.reference_cell);
    
    
    
    u_corrected = udlp_corrected + solution.problem.eta*uslp_corrected  + ...
        solution.u_avg(1) + 1i*solution.u_avg(2);
    u = udlp + solution.problem.eta*uslp + solution.u_avg(1) +...
        1i*solution.u_avg(2);
else
    
    % FMM can only evaluate for source=targets, so we include all the
    % target points as source points with strength 0
    
    qtmp1 = [solution.q(:,1).*weights; zeros(length(X(:)),1)];
    qtmp2 = [solution.q(:,2).*weights; zeros(length(X(:)),1)];
    ntmp1 = [n1(:); zeros(length(X(:)),1)];
    ntmp2 = [n2(:); zeros(length(X(:)),1)];
    
    xtmp = [xsrc; X(:)];
    ytmp = [ysrc; Y(:)];
    
    [udlp1, udlp2] = stokesDLPfmm(qtmp1, qtmp2, xtmp, ytmp, ntmp1, ntmp2);
    
    % note negative sign in from of double-layer
    udlp = -udlp1(length(xsrc)+1:end) - 1i*udlp2(length(xsrc)+1:end);
    
    disp('Beginning special quadrature...');
    
    [udlp_corrected,~] = mex_SQ_dlp(X(:)+1i*Y(:), domain.z, domain.zp,...
        domain.quad_weights, domain.panel_breaks, domain.wazp, domain.z32,...
        domain.zp32, domain.quad_weights32, domain.wazp32,...
        solution.q(:,1)+1i*solution.q(:,2),...
        udlp,domain.mean_panel_length,domain.extra.gridSolidmat, ...
        domain.extra.Nrows,domain.extra.Ncols,domain.extra.panels2wall,...
        domain.reference_cell);
    
    [uS, uR] = completion_contribution(domain.centers(2:end), X(:)+1i*Y(:),...
                solution.forces, solution.torques);
    
    u_corrected = udlp_corrected + uS + uR;
    u = udlp + uS + uR;

end

u1 = real(u);
u2 = imag(u);
u1_corrected = real(u_corrected);
u2_corrected = imag(u_corrected);

% find points inside domain by applying stresslet identity
if solution.problem.periodic
    [test1, test2] = StokesDLP_ewald_2p(xsrc, ysrc, X(:), Y(:), n1, n2,...
        ones(length(n1),1).*weights, zeros(length(n1),1).*weights, Lx, Ly);
else
    qtmp1 = [ones(length(xsrc),1).*weights; zeros(length(X(:)),1)];
    qtmp2 = [zeros(length(xsrc),1).*weights; zeros(length(X(:)),1)];
    ntmp1 = [n1(:); zeros(length(X(:)),1)];
    ntmp2 = [n2(:); zeros(length(X(:)),1)];
    
    xtmp = [xsrc; X(:)];
    ytmp = [ysrc; Y(:)];
    
    [test1, test2] = stokesDLPfmm(qtmp1, qtmp2, xtmp, ytmp, ntmp1, ntmp2);
    
    test1 = -test1(length(xsrc)+1:end);
    test2 = -test2(length(xsrc)+1:end);
    
end

% correct using special quadrature
[test,~] = mex_SQ_dlp(X(:)+1i*Y(:), domain.z, domain.zp, domain.quad_weights, ...
                domain.panel_breaks, domain.wazp, domain.z32, domain.zp32,...
                domain.quad_weights32, domain.wazp32,ones(length(n1),1) + 1e-14*1i,...
                test1 + 1i*test2,domain.mean_panel_length,domain.extra.gridSolidmat, ...
                domain.extra.Nrows,domain.extra.Ncols,domain.extra.panels2wall,...
                domain.reference_cell);

% anything that is greater than 0 is outside the fluid domain
outside = find(real(test) > -1e-6);
u1_corrected(outside) = nan;
u2_corrected(outside) = nan;
u1(outside) = nan;
u2(outside) = nan;

X(outside) = nan;
Y(outside) = nan;

U1c = reshape(u1_corrected, size(X));
U2c = reshape(u2_corrected, size(X));

U1 = reshape(u1, size(X));
U2 = reshape(u2, size(X));