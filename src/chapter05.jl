# begin hatfun
"""
    hatfun(t, k)

Create a piecewise linear hat function, where `t` is a
vector of n+1 interpolation nodes and `k` is an integer in 0:n
giving the index of the node where the hat function equals one.
"""
function hatfun(t, k)
    n = length(t) - 1
    return function (x)
        if k > 0 && t[k] ≤ x ≤ t[k+1]
            return (x - t[k]) / (t[k+1] - t[k])
        elseif k < n && t[k+1] ≤ x ≤ t[k+2]
            return (t[k+2] - x) / (t[k+2] - t[k+1])
        else
            return 0
        end
    end
end
# end hatfun

# begin plinterp
"""
    plinterp(t, y)

Construct a piecewise linear interpolating function for data values in
`y` given at nodes in `t`.
"""
function plinterp(t, y)
    n = length(t) - 1
    H = [hatfun(t, k) for k in 0:n]
    return x -> sum(y[k+1] * H[k+1](x) for k in 0:n)
end
# end plinterp

# begin spinterp
"""
    spinterp(t, y)

Construct a cubic not-a-knot spline interpolating function for data
values in `y` given at nodes in `t`.
"""
function spinterp(t, y)
    n = length(t) - 1
    h = [t[k+1] - t[k] for k in 1:n]

    # Preliminary definitions.
    Z = zeros(n, n)
    In = I(n)
    E = In[1:n-1, :]
    J = diagm(0 => ones(n), 1 => -ones(n - 1))
    H = diagm(0 => h)

    # Left endpoint interpolation:
    AL = [In Z Z Z]
    vL = y[1:n]

    # Right endpoint interpolation:
    AR = [In H H^2 H^3]
    vR = y[2:n+1]

    # Continuity of first derivative:
    A1 = E * [Z J 2 * H 3 * H^2]
    v1 = zeros(n - 1)

    # Continuity of second derivative:
    A2 = E * [Z Z J 3 * H]
    v2 = zeros(n - 1)

    # Not-a-knot conditions:
    nakL = [zeros(1, 3 * n) [1 -1 zeros(1, n - 2)]]
    nakR = [zeros(1, 3 * n) [zeros(1, n - 2) 1 -1]]

    # Assemble and solve the full system.
    A = [AL; AR; A1; A2; nakL; nakR]
    v = [vL; vR; v1; v2; 0; 0]
    z = A \ v

    # Break the coefficients into separate vectors.
    rows = 1:n
    a = z[rows]
    b = z[n.+rows]
    c = z[2*n.+rows]
    d = z[3*n.+rows]
    S = [Polynomial([a[k], b[k], c[k], d[k]]) for k in 1:n]

    # This function evaluates the spline when called with a value
    # for x.
    return function (x)
        if x < t[1] || x > t[n+1]    # outside the interval
            return NaN
        elseif x == t[1]
            return y[1]
        else
            k = findlast(x .> t)    # last node to the left of x
            return S[k](x - t[k])
        end
    end
end
# end spinterp

# begin fdweights
"""
    fdweights(t, m)

Compute weights for the `m`th derivative of a function at zero using
values at the nodes in vector `t`.
"""
function fdweights(t, m)
    # This is a compact implementation, not an efficient one.
    # Recursion for one weight.
    function weight(t, m, r, k)
        # Inputs
        #   t: vector of nodes
        #   m: order of derivative sought
        #   r: number of nodes to use from t
        #   k: index of node whose weight is found

        if (m < 0) || (m > r)        # undefined coeffs must be zero
            c = 0
        elseif (m == 0) && (r == 0)  # base case of one-point interpolation
            c = 1
        else                     # generic recursion
            if k < r
                c =
                    (t[r+1] * weight(t, m, r-1, k) - m * weight(t, m-1, r-1, k)) /
                    (t[r+1] - t[k+1])
            else
                numer = r > 1 ? prod(t[r] - x for x in t[1:r-1]) : 1
                denom = r > 0 ? prod(t[r+1] - x for x in t[1:r]) : 1
                β = numer / denom
                c =
                    β *
                    (m * weight(t, m - 1, r-1, r-1) - t[r] * weight(t, m, r-1, r-1))
            end
        end
        return c
    end
    r = length(t) - 1
    w = zeros(size(t))
    return [weight(t, m, r, k) for k in 0:r]
end
# end fdweights

# begin trapezoid
"""
    trapezoid(f, a, b, n)

Apply the trapezoid integration formula for integrand `f` over
interval [`a`,`b`], broken up into `n` equal pieces. Returns
the estimate, a vector of nodes, and a vector of integrand values at the
nodes.
"""
function trapezoid(f, a, b, n)
    h = (b - a) / n
    t = range(a, b, length = n + 1)
    y = f.(t)
    T = h * (sum(y[2:n]) + 0.5 * (y[1] + y[n+1]))
    return T, t, y
end
# end trapezoid

# begin intadapt
"""
    intadapt(f, a, b, tol)

Adaptively integrate `f` over [`a`,`b`] to within target error
tolerance `tol`. Returns the estimate and a vector of evaluation
nodes.
"""
function intadapt(f, a, b, tol, fa = f(a), fb = f(b), m = (a + b) / 2, fm = f(m))
    # Use error estimation and recursive bisection.
    # These are the two new nodes and their f-values.
    xl = (a + m) / 2
    fl = f(xl)
    xr = (m + b) / 2
    fr = f(xr)

    # Compute the trapezoid values iteratively.
    h = (b - a)
    T = [0.0, 0.0, 0.0]
    T[1] = h * (fa + fb) / 2
    T[2] = T[1] / 2 + (h / 2) * fm
    T[3] = T[2] / 2 + (h / 4) * (fl + fr)

    S = (4T[2:3] - T[1:2]) / 3      # Simpson values
    E = (S[2] - S[1]) / 15           # error estimate

    if abs(E) < tol * (1 + abs(S[2]))  # acceptable error?
        Q = S[2]                   # yes--done
        nodes = [a, xl, m, xr, b]      # all nodes at this level
    else
        # Error is too large--bisect and recurse.
        QL, tL = intadapt(f, a, m, tol, fa, fm, xl, fl)
        QR, tR = intadapt(f, m, b, tol, fm, fb, xr, fr)
        Q = QL + QR
        nodes = [tL; tR[2:end]]   # merge the nodes w/o duplicate
    end
    return Q, nodes
end
# end intadapt
