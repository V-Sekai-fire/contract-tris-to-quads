# Status

## What's real today

- `core/lean/TrisToQuads`: the full pipeline — triangle-adjacency candidate
  edges weighted the same way the upstream ILP weights them, a from-scratch
  box-constrained L-BFGS solver (two-loop recursion + gradient projection,
  Nocedal & Wright's algorithm), the penalty-relaxation objective/gradient
  for the matching constraint, and a greedy repair pass that guarantees a
  valid result regardless of how the continuous relaxation converged.
- Tested against a KNOWN-OPTIMAL fixture (a 2x2 grid of 8 triangles, whose
  correct answer — recover the 4 original unit squares — is independently
  obvious, not just "the solver agrees with itself"), plus a negative
  control (an isolated triangle: zero candidate edges, nothing dissolved).
  `lake exe tris_to_quads_test`: 7/7 checks pass.
- `guest/tris_to_quads.elf`: a real, verified RISC-V64 Linux ELF (correct
  file type, `tq_*` symbols `GLOBAL` in `.symtab`, `.sandbox_variant`
  reads `SBXV 28000000`), built with the workspace's own
  `riscv64-sysroot` clang/lld cross toolchain.

## What's not yet real

- The guest ELF's `tq_solve`/`tq_dissolved_edge_at` are explicit STUBS
  (see `guest/main.c`'s module doc) — they report failure, never a
  fabricated result. The real Lean solve above is not wired into the
  guest or ported to run on RISC-V yet; that's stage 2/3 of the
  `godot-sandbox-build-workflow` skill's C-ABI domain recipe.
- No binding to `sinew-mocap/solve`'s existing `core/lbfgsb` Slang/GPU
  pipeline. That package's kernels are wired to the cloth-drape problem
  specifically and are not a general bound-constrained solver entry
  point — `LBFGSB.lean` here is an independent, honestly-scoped
  from-scratch port, documented as such in its own module header.
- No shape-awareness in the matching (the ILP's own weighting is purely
  edge-length-based too, so this matches the upstream's actual
  objective, not a simplification of it) — a future iteration could add
  a quad-squareness term to the weight.
