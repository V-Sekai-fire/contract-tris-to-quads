/-
LBFGSB.lean — a from-scratch, general-purpose box-constrained L-BFGS
optimizer: the two-loop-recursion L-BFGS search direction (Nocedal &
Wright), with the iterate PROJECTED onto the box `[lo, hi]` after each
step (gradient-projection L-BFGS-B, Byrd/Lu/Nocedal/Zhu's simplified
scheme without the full active-set subspace minimization their original
paper adds). This is NOT a binding to `sinew-mocap/solve`'s existing
`core/lbfgsb` Slang/GPU pipeline — that package's kernels are wired to
one specific problem (cloth drape fitting) and are not a general
bound-constrained solver entry point a caller can hand an arbitrary
objective/gradient to. This module exists so `Solve.lean` has a REAL
solver to call, honestly scoped as a from-scratch port, not dressed up
as reusing the GPU pipeline it is not.
-/
namespace TrisToQuads

/-- A dense real vector, backed by `Array Float`. -/
abbrev Vec := Array Float

def Vec.zeros (n : Nat) : Vec := Array.replicate n 0.0

def Vec.add (a b : Vec) : Vec := Id.run do
  let mut out := a
  for i in [0:a.size] do
    out := out.set! i (a[i]! + b.getD i 0.0)
  return out

def Vec.scale (a : Vec) (s : Float) : Vec := a.map (· * s)

def Vec.sub (a b : Vec) : Vec := a.add (b.scale (-1.0))

def Vec.dot (a b : Vec) : Float := Id.run do
  let mut s : Float := 0
  for i in [0:a.size] do
    s := s + a[i]! * b.getD i 0.0
  return s

def Vec.norm (a : Vec) : Float := Float.sqrt (a.dot a)

/-- Project `x` componentwise onto the box `[lo, hi]`. -/
def Vec.clampBox (x : Vec) (lo hi : Float) : Vec :=
  x.map fun v => if v < lo then lo else if v > hi then hi else v

/-- One L-BFGS history pair: `s = x_{k+1} - x_k`, `y = g_{k+1} - g_k`. -/
structure HistoryPair where
  s : Vec
  y : Vec
  rho : Float  -- 1 / (y . s), cached
  deriving Inhabited

/-- Two-loop recursion (Nocedal & Wright, Algorithm 7.4): the L-BFGS
search direction `-H_k grad`, built from the last `history.size` pairs,
with the identity as the initial Hessian-inverse approximation (scaled by
`y.s / y.y` of the most recent pair when available — the standard
scaling heuristic that keeps the first step well-conditioned). -/
def twoLoopDirection (grad : Vec) (history : Array HistoryPair) : Vec := Id.run do
  let mut q := grad
  let mut alphas : Array Float := Array.replicate history.size 0.0
  for i in [0:history.size] do
    let j := history.size - 1 - i
    let pair := history[j]!
    let alpha := pair.rho * pair.s.dot q
    alphas := alphas.set! j alpha
    q := q.sub (pair.y.scale alpha)
  -- initial Hessian-inverse scaling
  let mut gamma : Float := 1.0
  if history.size > 0 then
    let last := history[history.size - 1]!
    let yy := last.y.dot last.y
    if yy > 1e-300 then
      gamma := (last.s.dot last.y) / yy
  let mut r := q.scale gamma
  for j in [0:history.size] do
    let pair := history[j]!
    let beta := pair.rho * pair.y.dot r
    r := r.add (pair.s.scale (alphas[j]! - beta))
  return r.scale (-1.0)  -- descent direction: -H grad

structure LBFGSBResult where
  x : Vec
  finalObjective : Float
  iterations : Nat
  deriving Repr

/-- Minimize `objective`/`gradient` over the box `[lo, hi]^n`, starting
from `x0`. Backtracking (Armijo) line search along the L-BFGS direction,
re-projected onto the box every step (so the iterate never leaves the
feasible box even mid-line-search) — the standard, simple gradient-
projection variant of L-BFGS-B. `maxIters`/`gradTol` bound the run; this
never loops unboundedly on a non-converging objective. -/
def solveBoxed (objective : Vec → Float) (gradient : Vec → Vec)
    (x0 : Vec) (lo hi : Float) (maxIters : Nat := 200) (gradTol : Float := 1e-6)
    (historyLimit : Nat := 10) : LBFGSBResult := Id.run do
  let mut x := x0.clampBox lo hi
  let mut g := gradient x
  let mut history : Array HistoryPair := #[]
  let mut iter : Nat := 0
  while iter < maxIters && g.norm > gradTol do
    iter := iter + 1
    let dir := twoLoopDirection g history
    -- Armijo backtracking: shrink the step until objective decreases
    -- enough, or the step is negligible.
    let mut step : Float := 1.0
    let f0 := objective x
    let gDotDir := g.dot dir
    let mut accepted := false
    let mut xNew := x
    let mut tries : Nat := 0
    while !accepted && tries < 30 do
      tries := tries + 1
      xNew := (x.add (dir.scale step)).clampBox lo hi
      let fNew := objective xNew
      if fNew <= f0 + 1e-4 * step * gDotDir || step < 1e-12 then
        accepted := true
      else
        step := step * 0.5
    let gNew := gradient xNew
    let s := xNew.sub x
    let y := gNew.sub g
    let sy := s.dot y
    if sy > 1e-10 then
      let pair : HistoryPair := { s := s, y := y, rho := 1.0 / sy }
      history := history.push pair
      if history.size > historyLimit then
        history := history.extract 1 history.size
    x := xNew
    g := gNew
  return { x := x, finalObjective := objective x, iterations := iter }

end TrisToQuads
