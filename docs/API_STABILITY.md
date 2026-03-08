# API Stability and Deprecation Policy

This document defines API stability expectations for Tinct as it moves from alpha to beta.

Current project maturity:

- Current version: `0.1.0-dev` (alpha)
- Beta policy target: `0.2.0-beta.1` and later beta tags
- Until the first beta tag is released, changes can still be breaking between commits

## What is considered stable in beta

Starting with `0.2.0-beta.1`, we treat these as the core public API surface:

- `Tinct.Component` callback contract (`init/1`, `update/2`, `view/1`)
- `Tinct.Command` constructors used by components
- `Tinct.View` / `Tinct.UI` authoring model used in user apps
- `Tinct.Test` public helpers used for headless UI tests

For these APIs, we avoid breaking changes during beta except when required for correctness or severe usability problems.

## What can still change during beta

Even in beta, some areas may still change more frequently:

- New modules and helper functions may be added
- Experimental options may be renamed when they are not yet widely used
- Internal modules and undocumented functions may change at any time
- Performance and rendering internals may evolve without notice as long as documented public behavior stays compatible

## Deprecation process and window

When we need to replace or remove a public beta API:

1. Mark the old API as deprecated in docs/changelog and, when practical, in code warnings.
2. Provide a documented migration path to the replacement API.
3. Keep the deprecated API available for at least one minor pre-1.0 release line (for example, from `0.2.x` through `0.3.x`) before removal.
4. Remove only in a later version with a clear breaking-change note.

For critical bug or security fixes, immediate changes may be required; those exceptions will be explicitly documented.

## Versioning expectations

Tinct uses pre-1.0 versioning. While on `0.x`:

- Minor version bumps (`0.2` -> `0.3`) may include breaking changes
- Patch version bumps (`0.2.1` -> `0.2.2`) should remain backward compatible except for urgent fixes
- Beta tags communicate intended stability, not a final guarantee until `1.0`

At `1.0`, we will publish stricter compatibility guarantees aligned with stable SemVer expectations.
