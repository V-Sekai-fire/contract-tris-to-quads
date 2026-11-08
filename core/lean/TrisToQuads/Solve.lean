/-
Solve.lean — the tris-to-quads continuous relaxation: maximize the
weighted sum of "dissolve this edge" variables `x_e in [0,1]`, penalized
by a quadratic penalty for violating "each triangle touches at most one
dissolved edge" (the upstream ILP's hard constraint, turned into a soft
penalty since `LBFGSB.solveBoxed` only knows box constraints).

  minimize   -sum_e w_e x_e  +  rho * sum_t max(0, sum_{e touching t} x_e - 1)^2
  subject to 0 <= x_e <= 1

After the continuous solve, `x_e > 0.5` is the candidate dissolve set;
a greedy REPAIR pass (highest-weight edge first) then drops any edge
whose triangle is already claimed by a higher-weight accepted edge, so
the final output is always a genuinely valid matching (every triangle in
at most one dissolved edge) regardless of how exactly the penalty
converged — the repair is what makes the result trustworthy, not the
continuous relaxation alone.
-/
import TrisToQuads.Mesh
import TrisToQuads.LBFGSB

namespace TrisToQuads

structure SolveResult where
  dissolvedEdges : Array CandidateEdge
  objectiveValue : Float   -- sum of weights of the dissolved edges (maximized)
  lbfgsIterations : Nat
  deriving Repr

/-- Triangle ids each candidate edge touches, per candidate index (0/1
entries into `triA`/`triB`), used to build the penalty term and its
gradient without recomputing adjacency per call. -/
private def trianglesOf (edges : Array CandidateEdge) (nTris : Nat) :
    Array (Array Nat) := Id.run do
  let mut byTri : Array (Array Nat) := Array.replicate nTris #[]
  for i in [0:edges.size] do
    let e := edges[i]!
    if e.triA < nTris then
      byTri := byTri.set! e.triA ((byTri[e.triA]!).push i)
    if e.triB < nTris then
      byTri := byTri.set! e.triB ((byTri[e.triB]!).push i)
  return byTri

def solve (m : TriMesh) (rho : Float := 20.0) : SolveResult := Id.run do
  let edges := candidateEdges m
  if edges.size == 0 then
    return { dissolvedEdges := #[], objectiveValue := 0, lbfgsIterations := 0 }
  let byTri := trianglesOf edges m.tris.size
  let weights := edges.map (·.weight)

  let objective : Vec → Float := fun x => Id.run do
    let mut linear : Float := 0
    for i in [0:x.size] do
      linear := linear + weights[i]! * x[i]!
    let mut penalty : Float := 0
    for triEdges in byTri do
      if triEdges.size > 0 then
        let mut s : Float := 0
        for i in triEdges do
          s := s + x[i]!
        let over := s - 1.0
        if over > 0 then
          penalty := penalty + over * over
    return -linear + rho * penalty

  let gradient : Vec → Vec := fun x => Id.run do
    let mut g : Vec := Array.replicate x.size 0.0
    for i in [0:x.size] do
      g := g.set! i (-weights[i]!)
    for triEdges in byTri do
      if triEdges.size > 0 then
        let mut s : Float := 0
        for i in triEdges do
          s := s + x[i]!
        let over := s - 1.0
        if over > 0 then
          for i in triEdges do
            g := g.set! i (g[i]! + rho * 2.0 * over)
    return g

  let x0 := Array.replicate edges.size 0.3   -- interior start, not a box corner
  let result := solveBoxed objective gradient x0 0.0 1.0

  -- repair pass: highest weight first, skip an edge if either of its
  -- triangles is already claimed.
  let order := (List.range edges.size).toArray.qsort fun i j =>
    result.x[i]! > result.x[j]!
  let mut claimed : Array Bool := Array.replicate m.tris.size false
  let mut chosen : Array CandidateEdge := #[]
  let mut chosenVal : Float := 0
  for i in order do
    let e := edges[i]!
    if result.x[i]! > 0.5 && !claimed.getD e.triA true && !claimed.getD e.triB true then
      claimed := claimed.set! e.triA true
      claimed := claimed.set! e.triB true
      chosen := chosen.push e
      chosenVal := chosenVal + e.weight

  return { dissolvedEdges := chosen, objectiveValue := chosenVal,
           lbfgsIterations := result.iterations }

end TrisToQuads
