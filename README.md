# contract-tris-to-quads

**A box-constrained L-BFGS solve for triangles-to-quads — not an ILP, and not a GPU binding.**

Blender's own tris-to-quads is a greedy angle threshold. The mathematically optimal version is an ILP ([Rulesobeyer/Optimized-Tris-to-Quads-Converter](https://github.com/Rulesobeyer/Optimized-Tris-to-Quads-Converter), a fork of [SaitoTsutomu/Tris-Quads-Ex](https://github.com/SaitoTsutomu/Tris-Quads-Ex)), solved with PuLP/CBC.

This repo poses the SAME problem — maximize a weighted sum of "dissolve this edge" choices, subject to each triangle touching at most one dissolved edge — as a continuous relaxation over `[0,1]^n`, solved with a real from-scratch two-loop-recursion L-BFGS optimizer (gradient-projected onto the box) plus a greedy repair pass that always returns a valid matching.

Verified against a known-optimal fixture, not just internal consistency: a flat 2x2 grid of 8 triangles has a mathematically obvious optimum (recover the 4 original unit squares), and the solver finds exactly that — plus a negative control (an isolated triangle has zero candidate edges and the solver reports nothing dissolved).

```sh
cd core/lean && lake build && lake exe tris_to_quads_test
```

Run that to see all 7 checks pass, including the box-constraint clamp test on the plain L-BFGS-B solver itself.

See `docs/STATUS.md` for what's real today (the Lean solve, tested) versus what's not yet (the guest ELF's `tq_solve` is still an honest stub — see `guest/main.c`).
