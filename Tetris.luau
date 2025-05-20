local Tetris = {
	Size = {X = 10, Y = 20},
	Pieces = require(script.Pieces)
}

local BoardSizeX = Tetris.Size.X
local BoardSizeY = Tetris.Size.Y
local GetRandomPiece = require(script.RandomPiece)

function Tetris.CopyBuffer(Buffer)
	local BufferSize = buffer.len(Buffer)

	local NewBuffer = buffer.create(BufferSize)
	buffer.copy(NewBuffer, 0, Buffer, 0, BufferSize)

	return NewBuffer
end

function Tetris.GetValue(Buffer, Index)
	return buffer.readi8(Buffer, Index)
end

function Tetris.PieceIsValid(Board, Piece, Y, X)
	local PieceSize = buffer.len(Piece)
	PieceSize = math.floor(math.sqrt(PieceSize))

	local Min, Max = PieceSize, 0

	for PieceOffset=0, buffer.len(Piece) - 1 do
		if Tetris.GetValue(Piece, PieceOffset) == 0 then
			continue
		end

		local OffsetX = PieceOffset % PieceSize

		if OffsetX < Min then
			Min = OffsetX
		elseif OffsetX > Max then
			Max = OffsetX
		end

		local Offset = (X + ((Y + 1) * BoardSizeX)) + 
			(BoardSizeX * math.floor(PieceOffset / PieceSize)) + 
			(PieceOffset % PieceSize)

		if Offset < 0 or Offset >= buffer.len(Board) or Tetris.GetValue(Board, Offset) > 0 then
			return false
		end
	end

	if X + Min < 0 or X + Max > BoardSizeX - 1 then
		return false
	end
	return true
end

function Tetris.GetPieceIndexes(Board, Piece, Y, X)
	local Indexes = {}
	local PieceSize = buffer.len(Piece)
	PieceSize = math.floor(math.sqrt(PieceSize))

	for PieceOffset=0, buffer.len(Piece) - 1 do
		local Value = Tetris.GetValue(Piece, PieceOffset)

		if Value > 0 then
			table.insert(
				Indexes, (X + ((Y + 1) * Tetris.Size.X)) + 
				(Tetris.Size.X * math.floor(PieceOffset / PieceSize)) + 
				(PieceOffset % PieceSize)
			)
			table.insert(Indexes, Value)
		end
	end

	return Indexes
end

function Tetris.AddPieceToBoard(Board, Piece, Y, X)
	Board = Tetris.CopyBuffer(Board)

	local Offset = nil
	
	for i, Value in Tetris.GetPieceIndexes(Board, Piece, Y, X) do
		if not Offset then
			Offset = Value
			continue
		end
		
		buffer.writei8(Board, Offset, Value)
		Offset = nil
	end

	return Board
end

function Tetris.CanMoveSide(Board, Piece, Y, X, Right)
	return Tetris.PieceIsValid(
		Board, Piece, Y, X + (Right and 1 or -1)
	)
end

function Tetris.CanRotate(Board, Piece, Y, X, Clockwise)
	local RotatedPiece = Tetris.Pieces.Rotate(Piece, Clockwise)
	return Tetris.PieceIsValid(
		Board, 
		RotatedPiece, 
		Y, X
	) and RotatedPiece
end

function Tetris.ClearLines(Board)
	Board = Tetris.CopyBuffer(Board)
	local ClearedLine = false

	repeat
		ClearedLine = false
		
		for Y=BoardSizeY, 1, -1 do
			local ClearLine = true

			for X=1, BoardSizeX do
				if Tetris.GetValue(Board, ((Y - 1) * BoardSizeX) + (X - 1)) > 0 then
					continue
				end

				ClearLine = false
				break
			end

			if not ClearLine then
				continue
			end

			local NewBoard = buffer.create(buffer.len(Board))

			if Y ~= 1 then
				buffer.copy(NewBoard, BoardSizeX, Board, 0, (Y - 1) * BoardSizeX)
			end

			if Y ~= BoardSizeY then
				local Offset = (Y) * BoardSizeX
				buffer.copy(NewBoard, Offset, Board, Offset, buffer.len(Board) - Offset)
			end

			Board = NewBoard
			ClearedLine = true
		end
	until not ClearedLine
	
	return Board
end

function Tetris.CanMoveDown(Board, Piece, Y, X)
	return Tetris.PieceIsValid(Board, Piece, Y + 1, X)
end

function Tetris.CopyGame(MainGame)
	return {
		Tetris.CopyBuffer(MainGame[1]),
		Tetris.CopyBuffer(MainGame[2]),
		Tetris.CopyBuffer(MainGame[3]),
		MainGame[4],
		MainGame[5],
		MainGame[6],
	}
end

function Tetris.new(CustomPosition)
	local PieceCenter = math.floor(BoardSizeX / 2) - 1

	local MainGame = CustomPosition or {
		buffer.create(BoardSizeX * BoardSizeY),
		GetRandomPiece(), -- current piece
		GetRandomPiece(),  -- next piece

		-1,			-- Piece pos Y
		PieceCenter,  -- piece pos X
		
		0.5 -- Rate
	}
	
	function MainGame:StartLoop(...: () -> nil)
		local Time = 0
		local NextRefresh = 0
		
		while true do 
			if Time < NextRefresh then
				repeat 
					Time += task.wait()
				until Time > NextRefresh
			end
			NextRefresh = MainGame[6] - (Time - NextRefresh)
			Time = 0

			local GameRunning = MainGame:Step()
			
			for i, Function in {...} do
				Function()
			end
			if not GameRunning then break end
		end
	end

	function MainGame:Step()
		if Tetris.CanMoveDown(MainGame[1], MainGame[2], MainGame[4], MainGame[5]) then
			MainGame[4] += 1
		else
			MainGame[1] = MainGame:GetBoard()
			MainGame[2] = MainGame[3]
			MainGame[3] = GetRandomPiece()

			if MainGame[4] == -1 then
				return false
			end

			MainGame[4] = -1
			MainGame[5] = PieceCenter

			MainGame[1] = Tetris.ClearLines(MainGame[1])
		end
		return true
	end

	function MainGame:Drop()
		repeat
			MainGame:Step()
		until MainGame[4] == -1
	end

	function MainGame:Rotate(Clockwise)
		local RotatedPiece = Tetris.CanRotate(MainGame[1], MainGame[2], MainGame[4], MainGame[5], Clockwise)
		if RotatedPiece then
			MainGame[2] = RotatedPiece
			return true
		end
	end

	function MainGame:Move(Side)
		if Tetris.CanMoveSide(MainGame[1], MainGame[2], MainGame[4], MainGame[5], Side) then
			MainGame[5] += (Side and 1 or -1)
			return true
		end
	end

	function MainGame:GetBoard()
		return Tetris.AddPieceToBoard(MainGame[1], MainGame[2], MainGame[4], MainGame[5])
	end

	return MainGame
end

return Tetris
