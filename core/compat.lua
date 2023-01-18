local _, BPGP = ...

local compat = {}
BPGP.compat = compat

function compat.SetResizeBounds(frame, minWidth, minHeight, maxWidth, maxHeight)
  minWidth = minWidth or 0
  minHeight = minHeight or 0

  if frame.SetResizeBounds then
    return frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
  end

  frame:SetMinResize(minWidth, minHeight)

  if maxWidth and maxHeight then
    frame:SetMaxResize(maxWidth, maxWidth)
  end
end
