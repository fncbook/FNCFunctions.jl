# begin shoot
"""
    shoot(ϕ, xspan, g₁, g₂, init)

Shooting method to solve a two-point boundary value problem with
ODE u'' = `ϕ`(x, u, u') for x in `xspan`, left boundary condition
`g₁`(u,u')=0, and right boundary condition `g₂`(u,u')=0. The
value `init` is an initial estimate for vector [u,u'] at x=a.

Returns vectors for the nodes, the solution u, and derivative u'.
"""
function shoot(ϕ, xspan, g₁, g₂, init, tol = 1e-5)
    # ODE posed as a first-order equation in 2 variables.
    shootivp = (v, p, x) -> [v[2]; ϕ(x, v[1], v[2])]

    # Evaluate the difference between computed and target values at x=b.
    function objective(s)
        IVP = ODEProblem(shootivp, s, float.(xspan))
        sol = solve(IVP, Tsit5(), abstol = tol / 10, reltol = tol / 10)
        x = sol.t
        y = sol
        return [g₁(s...), g₂(y.u[end]...)]
    end

    # Find the unknown quantity at x=a by rootfinding.
    x = []
    y = []   # these values will be overwritten
    s = levenberg(objective, init, xtol = tol)[:, end]

    # Use the stored last solution of the IVP.
    u, du_dx = y[1, :], y[2, :]
    return x, u, du_dx
end
# end shoot

# begin diffmat2
"""
    diffmat2(n, xspan)

Compute 2nd-order-accurate differentiation matrices on `n`+1 points
in the interval `xspan`. Returns a vector of nodes and the matrices
for the first and second derivatives.
"""
function diffmat2(n, xspan)
    a, b = xspan
    h = (b - a) / n
    x = [a + i * h for i in 0:n]   # nodes

    # Define most of Dₓ by its diagonals.
    dp = fill(0.5 / h, n)        # superdiagonal
    dm = fill(-0.5 / h, n)       # subdiagonal
    Dₓ = diagm(-1 => dm, 1 => dp)

    # Fix first and last rows.
    Dₓ[1, 1:3] = [-1.5, 2, -0.5] / h
    Dₓ[n+1, n-1:n+1] = [0.5, -2, 1.5] / h

    # Define most of Dₓₓ by its diagonals.
    d0 = fill(-2 / h^2, n + 1)    # main diagonal
    dp = ones(n) / h^2         # super- and subdiagonal
    Dₓₓ = diagm(-1 => dp, 0 => d0, 1 => dp)

    # Fix first and last rows.
    Dₓₓ[1, 1:4] = [2, -5, 4, -1] / h^2
    Dₓₓ[n+1, n-2:n+1] = [-1, 4, -5, 2] / h^2

    return x, Dₓ, Dₓₓ
end
# end diffmat2

# begin diffcheb
"""
    diffcheb(n, xspan)

Compute Chebyshev differentiation matrices on `n`+1 points in the
interval `xspan`. Returns a vector of nodes and the matrices for the
first and second derivatives.
"""
function diffcheb(n, xspan)
    x = [-cos(k * π / n) for k in 0:n]    # nodes in [-1,1]

    # Off-diagonal entries.
    c = [2; ones(n - 1); 2]    # endpoint factors
    dij = (i, j) -> (-1)^(i + j) * c[i+1] / (c[j+1] * (x[i+1] - x[j+1]))
    Dₓ = [dij(i, j) for i in 0:n, j in 0:n]

    # Diagonal entries.
    Dₓ[isinf.(Dₓ)] .= 0         # fix divisions by zero on diagonal
    s = sum(Dₓ, dims = 2)
    Dₓ -= diagm(s[:, 1])         # "negative sum trick"

    # Transplant to [a,b].
    a, b = xspan
    x = @. a + (b - a) * (x + 1) / 2
    Dₓ = 2 * Dₓ / (b - a)             # chain rule

    # Second derivative.
    Dₓₓ = Dₓ^2
    return x, Dₓ, Dₓₓ
end
# end diffcheb

# begin bvplin
"""
    bvplin(p, q, r, xspan, lval, rval, n)

Use finite differences to solve a linear bopundary value problem.
The ODE is u''+`p`(x)u'+`q`(x)u = `r`(x) on the interval `xspan`,
with endpoint function values given as `lval` and `rval`. There will
be `n`+1 equally spaced nodes, including the endpoints.

Returns vectors of the nodes and the solution values.
"""
function bvplin(p, q, r, xspan, lval, rval, n)
    x, Dₓ, Dₓₓ = diffmat2(n, xspan)

    P = diagm(p.(x))
    Q = diagm(q.(x))
    L = Dₓₓ + P * Dₓ + Q     # ODE expressed at the nodes

    # Replace first and last rows using boundary conditions.
    z = zeros(1, n)
    A = [[1 z]; L[2:n, :]; [z 1]]
    b = [lval; r.(x[2:n]); rval]

    # Solve the system.
    u = A \ b
    return x, u
end
# end bvplin

# begin bvp
"""
    bvp(ϕ, xspan, g₁, g₂, init)

Finite differences to solve a two-point boundary value problem with
ODE u'' = `ϕ`(x,u,u') for x in `xspan`, left boundary condition
`g₁`(u,u')=0, and right boundary condition `g₂`(u,u')=0. The value
`init` is an initial estimate for the values of the solution u at
equally spaced values of x, which also sets the number of nodes.

Returns vectors for the nodes and the values of u.
"""
function bvp(ϕ, xspan, g₁, g₂, init)
    n = length(init) - 1
    x, Dₓ, Dₓₓ = diffmat2(n, xspan)
    h = x[2] - x[1]

    function residual(u)
        # Residual of the ODE at the nodes.
        du_dx = Dₓ * u                   # discrete u'
        d2u_dx2 = Dₓₓ * u                # discrete u''
        f = d2u_dx2 - ϕ.(x, u, du_dx)

        # Replace first and last values by boundary conditions.
        f[1] = g₁(u[1], du_dx[1]) / h
        f[n+1] = g₂(u[n+1], du_dx[n+1]) / h
        return f
    end

    u = levenberg(residual, init)
    return x, u[end]
end
# end bvp

# begin fem
"""
    fem(c, s, f, a, b, n)

Use a piecewise linear finite element method to solve a two-point
boundary value problem. The ODE is (`c`(x)u')' + `s`(x)u = `f`(x) on
the interval [`a`,`b`], and the boundary values are zero. The
discretization uses `n` equal subintervals.

Return vectors for the nodes and the values of u.
"""
function fem(c, s, f, a, b, n)
    # Define the grid.
    h = (b - a) / n
    x = @. a + h * (0:n)

    # Templates for the subinterval matrix and vector contributions.
    Ke = [1 -1; -1 1]
    Me = (1 / 6) * [2 1; 1 2]
    fe = (1 / 2) * [1; 1]

    # Evaluate coefficent functions and find average values.
    cval = c.(x)
    cbar = (cval[1:n] + cval[2:n+1]) / 2
    sval = s.(x)
    sbar = (sval[1:n] + sval[2:n+1]) / 2
    fval = f.(x)
    fbar = (fval[1:n] + fval[2:n+1]) / 2

    # Assemble global system, one interval at a time.
    K = zeros(n - 1, n - 1)
    M = zeros(n - 1, n - 1)
    f = zeros(n - 1)
    K[1, 1] = cbar[1] / h
    M[1, 1] = sbar[1] * h / 3
    f[1] = fbar[1] * h / 2
    K[n-1, n-1] = cbar[n] / h
    M[n-1, n-1] = sbar[n] * h / 3
    f[n-1] = fbar[n] * h / 2
    for k in 2:n-1
        K[k-1:k, k-1:k] += (cbar[k] / h) * Ke
        M[k-1:k, k-1:k] += (sbar[k] * h) * Me
        f[k-1:k] += (fbar[k] * h) * fe
    end

    # Solve system for the interior values.
    u = (K + M) \ f
    u = [0; u; 0]      # put the boundary values into the result
    return x, u
end
# end fem
