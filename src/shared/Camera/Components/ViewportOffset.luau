local GuiService = game:GetService("GuiService")
local camera = workspace.CurrentCamera

--[[
	@class ViewportOffset
	Mapeia coordenadas globais de input para um viewport lógico baseado em um Frame.
	Usado para corrigir offset de câmera quando o workspace não ocupa a tela inteira.
]]

local ViewportOffset = {}
ViewportOffset.AbsPos = Vector2.zero
ViewportOffset.AbsSize = Vector2.zero

--[[*
	@constructor
	@param frame Frame
	@return ViewportOffset
]]
function ViewportOffset.Init(self: ViewportOffset, frame: Frame)
	assert(frame and frame:IsA("Frame"), "ViewportOffset requires a Frame")

	self.Frame = frame

	self:Update()
	frame:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
		self:Update()
	end)
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:Update()
	end)
end

--[[*
	@private
	Recalcula métricas absolutas do viewport.
]]
function ViewportOffset._Recompute(self: ViewportOffset)
	local frame = self.Frame
  self.AbsPos = Vector2.new(frame.AbsolutePosition.X, frame.AbsolutePosition.Y + GuiService:GetGuiInset().Y)
	self.AbsSize = frame.AbsoluteSize

	local absPos: Vector2 = self.AbsPos
	local absSize: Vector2 = self.AbsSize

	local halfSize: Vector2 = absSize * 0.5
	self.Center = absPos + halfSize
end

--[[*
	@method Update
	Deve ser chamado se a UI for redimensionada / movida.
]]
function ViewportOffset.Update(self: ViewportOffset)
  camera = workspace.CurrentCamera
	self:_Recompute()
end

--[[*
	@method GetCenter
	@return Vector2
]]
function ViewportOffset.GetCenter(self: ViewportOffset): Vector2
	return self.Center
end

--[[*
	@method ScreenToViewport
	Converte posição global da tela para coordenada local normalizada do viewport (-1 .. 1).
	@param screenPos Vector2
	@return Vector2
]]
function ViewportOffset.ScreenToViewport(self: ViewportOffset, screenPos: Vector2): Vector2
	local localPos = screenPos - self.AbsPos
	local size = self.AbsSize

	if size.X == 0 or size.Y == 0 then
		return Vector2.zero
	end

	local nx = (localPos.X / size.X) * 2 - 1
	local ny = (localPos.Y / size.Y) * 2 - 1

	return Vector2.new(nx, ny)
end

--[[*
	@method IsInside
	@param screenPos Vector2
	@return boolean
]]
function ViewportOffset.IsInside(self: ViewportOffset, screenPos: Vector2): boolean
	if not self.Frame then
		return false
	end

	local p = self.AbsPos
	local s = self.AbsSize

	return screenPos.X >= p.X
		and screenPos.Y >= p.Y
		and screenPos.X <= p.X + s.X
		and screenPos.Y <= p.Y + s.Y
end

function ViewportOffset.GetNormalizedOffset(self: ViewportOffset): Vector2
	if not self.Frame or not camera then
		return Vector2.zero
	end

	local screenSize = camera.ViewportSize
	if screenSize.X <= 0 or screenSize.Y <= 0 then
		return Vector2.zero
	end

	local screenCenter =
		screenSize / 2

	local delta = self.Center - screenCenter

	return Vector2.new(
		delta.X / screenSize.X,
		delta.Y / screenSize.Y
	)
end

export type ViewportOffset = typeof(ViewportOffset) & {
	Frame: Frame,
	AbsPos: Vector2,
	AbsSize: Vector2,
	Center: Vector2,
}

return ViewportOffset :: ViewportOffset
