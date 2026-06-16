# Material Graph Studio Plugin

Roblox Studio plugin source for visually authoring `MaterialAnimation` workspaces.

The plugin edits an in-memory graph and exports a ModuleScript into:

`ReplicatedStorage.DirectPackages.MaterialAnimation.Workspaces`

Generated modules follow the runtime format:

- `Workspace.Values`
- `Workspace.Bakes`
- `Nodes`
- `SurfaceAppearance`

