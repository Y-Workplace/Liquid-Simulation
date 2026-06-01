local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EventTree = require(ReplicatedStorage.Packages.EventTree)

export type VoidCallable<Args...> = EventTree.CallableModule<Args...>
export type VoidProvider<Args...> = EventTree.ProviderModule<Args...>

export type GetCameraProvider = VoidProvider<Camera>
export type GetFocusPointProvider = VoidProvider<Vector3>
export type GetOrthographicModeProvider = VoidProvider<boolean>
export type GetModeProvider = VoidProvider<"Free" | "Orbital">
export type GetFixedDistanceProvider = VoidProvider<number>
export type GetCameraRotationAnglesProvider = VoidProvider<number, number>

export type InitCallable = VoidCallable<>
export type StartCallable = VoidCallable<>
export type TogglePerspectiveCallable = VoidCallable<boolean?, boolean?>
export type ViewOrbitDirectionCallable = VoidCallable<string?, number?, number?>
export type FocusOnObjectCallable = VoidCallable<>
export type ChangeFocusPointValueCallable = VoidCallable<Vector3>
export type ChangeFixedDistanceValueCallable = VoidCallable<number>
export type ActiveFreeModeCallable = VoidCallable<>
export type RequestRefreshCallable = VoidCallable<boolean?>

export type CameraTree = {
	GetCamera: {
		Provider: GetCameraProvider,
	},
	GetFocusPoint: {
		Provider: GetFocusPointProvider,
	},
	GetOrthographicMode: {
		Provider: GetOrthographicModeProvider,
	},
	GetMode: {
		Provider: GetModeProvider,
	},
	GetFixedDistance: {
		Provider: GetFixedDistanceProvider,
	},
	GetCameraRotationAngles: {
		Provider: GetCameraRotationAnglesProvider,
	},

	Init: {
		Callable: InitCallable,
	},
	Start: {
		Callable: StartCallable,
	},
	TogglePerspective: {
		Callable: TogglePerspectiveCallable,
	},
	ViewOrbitDirection: {
		Callable: ViewOrbitDirectionCallable,
	},
	FocusOnObject: {
		Callable: FocusOnObjectCallable,
	},
	ChangeFocusPointValue: {
		Callable: ChangeFocusPointValueCallable,
	},
	ChangeFixedDistanceValue: {
		Callable: ChangeFixedDistanceValueCallable,
	},
	ActiveFreeMode: {
		Callable: ActiveFreeModeCallable,
	},
	RequestRefresh: {
		Callable: RequestRefreshCallable,
	},
} & EventTree.EventTreeNode

return {}
