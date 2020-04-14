function [U1c, U2c, X, Y, U1, U2] = evaluate_velocity(solution, N)

Lx = solution.domain.Lx;
Ly = solution.domain.Ly;

domain = solution.domain;

xsrc = real(solution.domain.z);
ysrc = imag(solution.domain.z);
n1 = real(-1i*solution.domain.zp)./abs(solution.domain.zp);
n2 = imag(-1i*solution.domain.zp)./abs(solution.domain.zp);
weights = solution.domain.wazp;

x = linspace(min(xsrc), max(xsrc), N);
y = linspace(min(ysrc), max(ysrc), N);

[X,Y] = meshgrid(x,y);

[uslp1, uslp2] = StokesSLP_ewald_2p(xsrc, ysrc, X(:), Y(:),...
                solution.q(:,1).*weights, solution.q(:,2).*weights, Lx, Ly, 'verbose', 1);
            
[udlp1, udlp2] = StokesDLP_ewald_2p(xsrc, ysrc, X(:), Y(:), n1, n2,...
                solution.q(:,1).*weights, solution.q(:,2).*weights, Lx, Ly, 'verbose', 1);
            
disp('Beginning special quadrature...');

uslp = uslp1 + 1i*uslp2;
udlp = udlp1 + 1i*udlp2;

[uslp_corrected,~] = mex_SQ_slp(X(:)+1i*Y(:), domain.z, domain.zp, domain.quad_weights, ...
                domain.panel_breaks, domain.wazp, domain.z32, domain.zp32,...
                domain.quad_weights32, domain.wazp32, solution.q(:,1)+1i*solution.q(:,2),...
                uslp,domain.mean_panel_length,domain.extra.gridSolidmat, ...
                domain.extra.Nrows,domain.extra.Ncols,domain.extra.panels2wall,...
                domain.reference_cell);
 
[udlp_corrected,~] = mex_SQ_dlp(X(:)+1i*Y(:), domain.z, domain.zp, domain.quad_weights, ...
                domain.panel_breaks, domain.wazp, domain.z32, domain.zp32,...
                domain.quad_weights32, domain.wazp32, solution.q(:,1)+1i*solution.q(:,2),...
                udlp,domain.mean_panel_length,domain.extra.gridSolidmat, ...
                domain.extra.Nrows,domain.extra.Ncols,domain.extra.panels2wall,...
                domain.reference_cell);
            


u_corrected = udlp_corrected + solution.eta*uslp_corrected  + solution.u_avg(1) + 1i*solution.u_avg(2);
u = udlp + solution.eta*uslp + solution.u_avg(1) + 1i*solution.u_avg(2);

u1 = real(u);
u2 = imag(u);
u1_corrected = real(u_corrected);
u2_corrected = imag(u_corrected);

% find points inside domain by applying stresslet identity
test = StokesDLP_ewald_2p(xsrc, ysrc, X(:), Y(:), n1, n2,...
        ones(length(n1),1).*weights, zeros(length(n1),1).*weights, Lx, Ly);


outside = find(test < 1e-6);

u1_corrected(outside) = nan;
u2_corrected(outside) = nan;

u1(outside) = nan;
u2(outside) = nan;

U1c = reshape(u1_corrected, size(X));
U2c = reshape(u2_corrected, size(X));

U1 = reshape(u1, size(X));
U2 = reshape(u2, size(X));