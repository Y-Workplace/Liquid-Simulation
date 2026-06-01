local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EventTree = require(ReplicatedStorage.Packages.EventTree)

export type VoidCallable<Args...> = EventTree.CallableModule<Args...>
export type VoidProvider<Args...> = EventTree.ProviderModule<Args...>

export type GetZoomToMousePositionProvider = VoidProvider<boolean>
export type GetPanBtnProvider = VoidProvider<boolean>
export type GetZoomBtnProvider = VoidProvider<boolean>

export type InitCallable = VoidCallable<>
export type StartCallable = VoidCallable<>
export type SetZoomToMousePositionCallable = VoidCallable<boolean>
export type SetPanBtnCallable = VoidCallable<boolean>
export type SetZoomBtnCallable = VoidCallable<boolean>
export type SetIsPanningCallable = VoidCallable<boolean>
export type SetIsPanningForBtnCallable = VoidCallable<boolean>
export type SetPanZoomingCallable = VoidCallable<boolean>
export type SetPanZoomingForBtnCallable = VoidCallable<boolean>

export type MovementTree = {
	GetZoomToMousePosition: {
		Provider: GetZoomToMousePositionProvider,
	},
	GetPanBtn: {
		Provider: GetPanBtnProvider,
	},
	GetZoomBtn: {
		Provider: GetZoomBtnProvider,
	},

	Init: {
		Callable: InitCallable,
	},
	Start: {
		Callable: StartCallable,
	},
	SetZoomToMousePosition: {
		Callable: SetZoomToMousePositionCallable,
	},
	SetPanBtn: {
		Callable: SetPanBtnCallable,
	},
	SetZoomBtn: {
		Callable: SetZoomBtnCallable,
	},
	SetIsPanning: {
		Callable: SetIsPanningCallable,
	},
	SetIsPanningForBtn: {
		Callable: SetIsPanningForBtnCallable,
	},
	SetPanZooming: {
		Callable: SetPanZoomingCallable,
	},
	SetPanZoomingForBtn: {
		Callable: SetPanZoomingForBtnCallable,
	},
} & EventTree.EventTreeNode

return {}
