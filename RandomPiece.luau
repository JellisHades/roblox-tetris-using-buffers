local IndexList = {}

local Pieces = require(script.Parent.Pieces)

for i=1, #Pieces do
	table.insert(IndexList, i)
end

local function GetRandomPiece()
	local IndexIndexList = math.random(1, #IndexList)
	local Index = IndexList[IndexIndexList]
	table.remove(IndexList, IndexIndexList)

	if #IndexList <= 0 then
		for i=1, #Pieces do
			table.insert(IndexList, i)
		end
	end

	return Pieces.NewPiece(Index, Index)
end

return GetRandomPiece
