using FNCFunctions
using Test
using LinearAlgebra, OrdinaryDiffEq

@testset "Chapter 1" begin
	@test FNC.horner([-1,3,-3,1], 1.6) ≈ 0.6^3
end

@testset "Chapter 2" begin
	A = [ 1 2 3 0; -1 1 2 -1; 3 1 2 4; 1 1 1 1 ]
	L, U = FNC.lufact(A)
	@test norm(L*U - A) < 100eps()
	@test norm(U - triu(U)) < 100eps()
	@test norm(L - tril(L)) < 100eps()
	b = [1,10,0,-1] / 5;
	@test norm(L\b - FNC.forwardsub(L,b)) < 100eps()
	@test norm(U\b - FNC.backsub(U,b)) < 100eps()
	L, U, p = FNC.plufact(A)
	@test norm(L*U - A[p,:]) < 100eps()
	@test norm(U - triu(U)) < 100eps()
	@test norm(L - tril(L)) < 100eps()
end

@testset "Chapter 3" begin
	A = [3 4 5;-1 0 1;4 2 0; 1 1 2; 3 -4 1]
	b = 5:-1:1
	@test FNC.lsnormal(A, b) ≈ A\b
	@test FNC.lsqrfact(A, b) ≈ A\b
	Q,R = qr(A)
	QQ,RR = FNC.qrfact(A)
	@test Matrix(Q) ≈ QQ[:, 1:3]
	@test R ≈ RR[1:3,:]
end

@testset "Chapter 4" begin

	for c in [2,4,7.5,11]
		f = x -> exp(x) - x - c;
		dfdx = x -> exp(x) - 1;
		x = FNC.newton(f,dfdx,1.0);  r = x[end];
		@test abs(f(r)) < 100eps()
	end

	for c in [2,4,7.5,11]
		f = x -> exp(x) - x - c;
		dfdx = x -> exp(x) - 1;
		x = FNC.secant(f,3,0.5);  r = x[end];
		@test abs(f(r)) < 100eps()
	end

	function nlfun(x)
		f = zeros(3)
		f[1] = exp(x[2]-x[1]) - 2;
		f[2] = x[1]*x[2] + x[3];
		f[3] = x[2]*x[3] + x[1]^2 - x[2];
		return f
	end
	function nljac(x)
		J = zeros(3,3)
		J[1,:] = [-exp(x[2]-x[1]),exp(x[2]-x[1]), 0]
		J[2,:] = [x[2], x[1], 1]
		J[3,:] = [2*x[1], x[3]-1, x[2]]
		return J
	end

	x = FNC.newtonsys(nlfun, nljac, [0,0,0]);
	@test norm(nlfun(x[end])) < 100eps()
	x = FNC.newtonsys(nlfun, nljac, [1,2,3]);
	@test norm(nlfun(x[end])) < 100eps()

	x = FNC.levenberg(nlfun, [10,-4,-3])
	@test norm(nlfun(x[end])) < 1e-12

end

@testset "Chapter 5" begin
	f = t->cos(5t)
	Q,t = FNC.intadapt(f,-1,3,1e-8)
	@test Q ≈ (sin(15)+sin(5))/5 rtol = 1e-5
	T,_ = FNC.trapezoid(f,-1,3,820)
	@test T ≈ (sin(15)+sin(5))/5 rtol = 1e-4

	t = [-2,-0.5,0,1,1.5,3.5,4]/10
	w = FNC.fdweights(t.-0.12,2)
	f = x->cos(3x)
	@test dot(w,f.(t)) ≈ -9cos(0.36) rtol = 1e-3

	t = [-2,-0.5,0,1,1.5,3.5,4]/10
	H = FNC.hatfun(t,5)
	@test H(0.22) ≈ (0.22-t[5])/(t[6]-t[5])
	@test H(.38) ≈ (t[7]-.38)/(t[7]-t[6])
	@test H(0.06)==0
	@test H(t[6])==1
	@test H(t[7])==0
	@test H(t[1])==0
	p = FNC.plinterp(t,f.(t))
	@test p(0.22) ≈ f(t[5]) + (f(t[6])-f(t[5]))*(0.22-t[5])/(t[6]-t[5])
	S = FNC.spinterp(t,exp.(t))
	x = [-.17,-0.01,0.33,.38]
	@test S.(x) ≈ exp.(x) rtol = 1e-5
	@test S.(t) ≈ exp.(t) rtol = 1e-11
end

@testset "Chapter 6" begin
	f = (u,p,t) -> u + p*t^2
	û = exp(1.5) - 2*(-2 + 2*exp(1.5) - 2*1.5 - 1.5^2)
	ivp = ODEProblem(f, 1, (0,1.5), -2)
	t,u = FNC.euler(ivp,4000)
	@test û ≈ u[end] rtol = 0.005
	t,u = FNC.am2(ivp,4000)
	@test û ≈ u[end] rtol = 0.005

	g = (u,p,t) -> [t+p-sin(u[2]),u[1]]
	ivp = ODEProblem(g,[-1.,4],(1.,2.),-6)
	sol = solve(ivp,Tsit5())
	t,u = FNC.euler(ivp,4000)
	@test u[end] ≈ sol.u[end] rtol=0.004
	t,u = FNC.ie2(ivp,4000)
	@test u[end] ≈ sol.u[end] rtol=0.0005
	t,u = FNC.rk4(ivp,800)
	@test u[end] ≈ sol.u[end] rtol=0.0005
	t,u = FNC.ab4(ivp,800)
	@test u[end] ≈ sol.u[end] rtol=0.0005
	t,u = FNC.rk23(ivp,1e-4)
	@test u[end] ≈ sol.u[end] rtol=0.0005
	t,u = FNC.am2(ivp,2000)
	@test u[end] ≈ sol.u[end] rtol=0.0005
end

@testset "Chapter 8" begin
	V = randn(4,4)
	D = diagm([-2,0.4,-0.1,0.01])
	A = V*D/V;

	γ,x = FNC.poweriter(A,30)
	@test γ[end] ≈ -2 rtol=1e-10
	@test abs( dot(x,V[:,1])/(norm(V[:,1])*norm(x)) ) ≈ 1 rtol=1e-10

	γ,x = FNC.inviter(A,0.37,15)
	@test γ[end] ≈ 0.4 rtol=1e-10
	@test abs( dot(x,V[:,2])/(norm(V[:,2])*norm(x)) ) ≈ 1 rtol=1e-10

	Q,H = FNC.arnoldi(A,ones(4),4)
	@test A*Q[:,1:4] ≈ Q*H

	x,res = FNC.gmres(A,ones(4),3)
	@test norm(ones(4) - A*x) ≈ res[end]
	x,res = FNC.gmres(A,ones(4),4)
	@test A*x ≈ ones(4)
end

@testset "Chapter 9" begin
	f = x -> exp(sin(x)+x^2)
	t = [-cos(k*π/40) for k in 0:40 ]
	p = FNC.polyinterp(t, f.(t))
	@test all(p(x) ≈ f(x) for x in range(-1, 1, 501))
	@test p(-1) == f(-1)

	f = x -> exp(sin(π*x))
	n = 30
	t = [ 2k/(2n+1) for k in -n:n ]
	p = FNC.triginterp(t, f.(t))
	@test all(p(x) ≈ f(x) for x in range(-1, 1, 501))
	@test p(0) == f(0)
	t = [ k/n for k in -n:n-1 ]
	p = FNC.triginterp(t,f.(t))
	@test all(p(x) ≈ f(x) for x in range(-1, 1, 501))

	F = x -> tan(x/2-0.2)
	f = x -> 0.5*sec(x/2-0.2)^2
	@test FNC.ccint(f,40)[1] ≈ F(1)-F(-1)
	@test FNC.glint(f,40)[1] ≈ F(1)-F(-1)

	f = x -> 1/(32+2x^4)
	@test FNC.intinf(f,1e-9)[1] ≈ sqrt(2)*π/32 rtol=1e-5

	f = x -> (1-x)/( sin(x)^0.5 )
	@test FNC.intsing(f,1e-8)[1] ≈ 1.34312 rtol=1e-5
end

@testset "Chapter 10" begin
	λ = 0.6
	phi = (r,w,dwdr) -> λ/w^2 - dwdr/r;
	a = eps();  b = 1;
	g₁ = (u,du)->du    # Neumann at left
	g₂ = (u,du)->u-1   # Dirichlet at right

	r,w,dwdx = FNC.shoot(phi,(a,b),g₁,g₂,[0.8,0])
	@test w[1] ≈ 0.78776 rtol=1e-4

	f = x -> exp(x^2-3x)
	df = x -> (2x-3)*f(x)
	ddf = x -> ((2x-3)^2+2)*f(x)

	t,D,DD = FNC.diffmat2(400,(-0.5,2))
	@test df.(t) ≈ D*f.(t) rtol=1e-3
	@test ddf.(t) ≈ DD*f.(t) rtol=1e-3
	t,D,DD = FNC.diffcheb(80,(-0.5,2))
	@test df.(t) ≈ D*f.(t) rtol=1e-7
	@test ddf.(t) ≈ DD*f.(t) rtol=1e-7

	exact = x -> exp(sin(x));
	p = x -> -cos(x);
	q = sin;
	r = x -> 0;
	x,u = FNC.bvplin(p,q,r,[0,pi/2],1,exp(1),300);
	@test u ≈ exact.(x) rtol=1e-3

	ϕ = (t,θ,ω) -> -0.05*ω - sin(θ);
	g1(u,du) = u-2.5
	g2(u,du) = u+2
	init = collect(range(2.5,-2,length=101));

	t,θ = FNC.bvp(ϕ,[0,5],g1,g2,init)
	@test θ[7] ≈ 2.421850016880724 rtol=1e-10

	c = x -> x^2;
	 q = x -> 4;
	f = x -> sin(π*x);
	x,u = FNC.fem(c,q,f,0,1,100)
	@test u[33] ≈ 0.1641366907307196 rtol=1e-10
end

@testset "Chapter 11" begin
	s = x -> sin(π*(x-0.2))
	c = x -> cos(π*(x-0.2))
	f = x -> 1 + s(x)^2
	df = x -> 2π*s(x)*c(x)
	ddf = x -> 2π^2*(c(x)^2 - s(x)^2)

	t,D,DD = FNC.diffper(400,(0,2))
	@test df.(t) ≈ D*f.(t) rtol=1e-3
	@test ddf.(t) ≈ DD*f.(t) rtol=1e-3

	phi = (t,x,u,uₓ,uₓₓ) -> uₓₓ + t*u
	g1(u,ux) = ux;
	g2(u,ux) = u-1;
	init(x) = x^2;
	x,u = FNC.parabolic(phi,(0,1),40,g1,g2,(0,2),init);
	@test u(0.5)[21] ≈ 0.845404 rtol=1e-3
	@test u(1)[end] ≈ 1 rtol=1e-4
	@test u(2)[1] ≈ 2.45692 rtol=1e-3
end

@testset "Chapter 13" begin

	f = (x,y) -> -sin(3*x.*y-4*y)*(9*y^2+(3*x-4)^2);
	g = (x,y) -> sin(3*x*y-4*y);
	xspan = [0,1];  yspan = [0,2];
	x,y,U = FNC.poissonfd(f,g,60,xspan,60,yspan);
	X = [x for x in x,y in y];
	Y = [y for x in x,y in y];
	@test g.(X,Y) ≈ U rtol=1e-3

	λ = 1.5
	function pde(X,Y,U,Ux,Uxx,Uy,Uyy)
		return @. Uxx + Uyy - λ/(U+1)^2   # residual
	end
	g = (x,y) -> x+y     # boundary condition
	u = FNC.elliptic(pde,g,30,[0,2.5],24,[0,1]);
	@test u(1.25,0.5) ≈ 1.7236921361 rtol = 1e-6
	@test u(1,0) ≈ 1 rtol = 1e-6
end
