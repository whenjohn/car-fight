# Car Fight branch and worktree ledger

Updated: 2026-09-02

This is a read-only cleanup inventory. It does not authorize deleting branches,
tags, worktrees, or archives. Branch deletion remains a separate owner-approved
operation.

## Snapshot

- Canonical branch: `master` at `d949ba7`.
- Active cleanup branch: `codex/code-health-audit` at `bcf13d9`.
- Local branches: 30 total; 22 non-`master` branches are fully merged and seven
  branches are not merged into `master` (including the active cleanup branch).
- Remote-tracking refs: 31 under `origin`.
- Registered worktrees: two, both current and intentional:
  `/Users/johnnguyen/Projects/car-fight` and
  `/Users/johnnguyen/Projects/car-fight-code-health`.
- Recovery tag: `pre-godot-46-2026-08-31`.

Merged means the branch tip is an ancestor of `master`; it does not mean the
branch name has been deleted or that deleting it has been approved.

## Keep

These refs are active or explicitly named as recovery/safety evidence:

| Ref | Tip | Reason |
| --- | --- | --- |
| `master` | `d949ba7` | Canonical development branch. |
| `codex/code-health-audit` | `bcf13d9` | Active cleanup work; keep until reviewed and merged. |
| `pre-godot-46-2026-08-31` | tag | Explicit pre-migration recovery point. |
| `integration/godot-46-rapier-0835` | `e1923ab` | Explicit accepted Godot 4.6 recovery point. |
| `codex/forwardplus-46-rendering` | `6f9e6aa` | Explicit approved rendering-study recovery point. |
| `origin/codex/godot47-resurrection` | `7027700` | Explicit approved Godot 4.7 resurrection checkpoint. |
| `diagnostics/render-isolation` | `64aafcb` | Required preserved Intel/display investigation evidence. |
| `diagnostics/mac-intel-fullscreen` | `72afb20` | Required preserved Intel/display investigation evidence. |
| `diagnostics/g2-render-bisect` | `07f9462` | Required preserved Intel/display investigation evidence. |

Keep both local and `origin` copies where both exist. Do not merge the three
diagnostic branches into `master`.

The following unmerged rendering experiment refs also remain on hold because
their unique tips are not reachable from `master`: `codex/intel-single-shadow-test`
at `0819bfd`, `codex/master-no-ssao-control` at `2d28b48`, and
`codex/post-downgrade-lighting` at `f672aec`. Before removing any of them, pin
the desired commits with an explicit tag or verified canonical-repository
bundle and update historical documentation that relies on them.

## Merged cleanup candidates

Every branch below is fully reachable from `master`. The names are therefore
redundant for object recovery, but deleting any of them still requires owner
approval.

Local branch candidates (20):

- `codex/more-vehicles`
- `codex/rendering-styles`
- `codex/sunlit-aerial-rendering`
- `codex/trees-foliage-lighting`
- `dots-auto-pickups`
- `feat/det-defense`
- `feat/grass`
- `feat/occluded-silhouette`
- `feat/offscreen-indicators`
- `feat/web`
- `feature/area-weapon`
- `feature/browser-networking`
- `feature/homing-missile`
- `feature/network-shaping`
- `feature/networking-1`
- `feature/networking-2`
- `feature/oil-slick`
- `feature/pickup-dropoff`
- `feature/rc-orb`
- `feature/vehicle-selection`

Remote branch candidates (20):

- `origin/codex/more-vehicles`
- `origin/codex/sense-of-speed`
- `origin/codex/skid-marks`
- `origin/codex/sunlit-aerial-rendering`
- `origin/codex/trees-foliage-lighting`
- `origin/dots-auto-pickups`
- `origin/feat/det-defense`
- `origin/feat/grass`
- `origin/feat/occluded-silhouette`
- `origin/feat/offscreen-indicators`
- `origin/feat/web`
- `origin/feature/area-weapon`
- `origin/feature/browser-networking`
- `origin/feature/homing-missile`
- `origin/feature/network-shaping`
- `origin/feature/networking-1`
- `origin/feature/networking-2`
- `origin/feature/oil-slick`
- `origin/feature/pickup-dropoff`
- `origin/feature/rc-orb`

`codex/rendering-styles` and `feature/vehicle-selection` exist only as local
branches. `origin/codex/sense-of-speed` and `origin/codex/skid-marks` exist only
as remote-tracking refs in this checkout.

## Archive verification

The private `whenjohn/car-fight-archives` repository exists and its 2026-09-02
README records verified bundles for the retired cleanroom repository and the
accepted Godot 4.6 Forward+ cleanroom. Those archives do not claim to replace
the canonical repository's branch refs listed above. They support the retained
historical evidence but are not used as justification for deleting unmerged
canonical branches.

## Approved deletion procedure

If the owner later approves cleanup:

1. Refresh refs and repeat the ancestor checks against the then-current
   `master`.
2. Confirm neither registered worktree uses a candidate branch.
3. Delete only the specifically approved local merged branches with safe branch
   deletion; do not force-delete.
4. Delete only the specifically approved remote branches.
5. Fetch/prune, repeat this inventory, and confirm the keep refs and tag still
   resolve to their recorded commits.
