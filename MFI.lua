------------------------------------------------------------------------------------------------------
--  Индикатор MFI Билла Вильямса с учётом 10% фильтра изменения объёма и MFI, о чём говорит автор.  --
--  Разработчик: Евгений А.                                                                         --
--  Особенность: может выводить как гистограммы, так и цветные столбики без учёта их высоты.        --
--  Автор говорит, что значение MFI не важно, а главное цвет столбика.                              --
--  https://github.com/Andry74/BW_MFI                                                               --
------------------------------------------------------------------------------------------------------


--  Основные параметры
--  -------------------
--  Delta = 10 - 10% фильтр.
--  Histogram = off - вывод цветных линий, а не гистограммы, т.к. автор говорит, что значение MFI не важно, а главное цвет.
--  Четыре цветные линии:
--    * Зелёный
--    * Увядающий
--    * Фальшивый
--    * Приседающий



Settings = {
	Name = "Andry. Bill Williams MFI",
	Delta = 10,
	Histogram="off",
	line = {
		{
		Width = 2,
		Name = "Зелёный", 
		Type = TYPE_HISTOGRAM, 
		Color = RGB(0, 206, 0)
		},
		{
		Width = 2,
		Name = "Увядающий", 
		Type = TYPE_HISTOGRAM, 
		Color = RGB(0, 0, 0)
		},
		{
		Width = 2,
		Name = "Фальшивый", 
		Type = TYPE_HISTOGRAM, 
		Color = RGB(21, 63, 255)
		},
		{
		Width = 3,
		Name = "Приседающий", 
		Type = TYPE_HISTOGRAM, 
		Color = RGB(255, 0, 0)
		}
	},
	Round = "off",
	Multiply = 1
}


local Prev_MFI = 0
local Prev_Vol = 0


function Init()
	func = BWMFI()
	Delta = Settings.Delta / 100 + 1
	return #Settings.line
end

function OnCalculate(Index)
	local MFI = ConvertValue(Settings, func(Index, Settings))
	local Delta = Settings.Delta / 100 + 1
	if Index == 1 then Prev_MFI = 0 Prev_Vol = V(Index) or 0 end
	if MFI then
		
		-- Зелёный
		if MFI > Prev_MFI*Delta and V(Index) > Prev_Vol*Delta then
			Prev_MFI = MFI
			Prev_Vol = V(Index)
			if Settings.Histogram=="off" then   return 1,nil,nil,nil   else   return MFI,nil,nil,nil   end
		
		-- Увядающий
		elseif MFI <= Prev_MFI*Delta and V(Index) <= Prev_Vol*Delta then
			Prev_MFI = MFI
			Prev_Vol = V(Index)
			if Settings.Histogram=="off" then   return nil,1,nil,nil   else   return nil,MFI,nil,nil   end
		
		-- Фальшивый
		elseif MFI > Prev_MFI*Delta and V(Index) <= Prev_Vol*Delta then
			Prev_MFI = MFI
			Prev_Vol = V(Index)
			if Settings.Histogram=="off" then   return nil,nil,1,nil   else   return nil,nil,MFI,nil   end
		
		-- Приседающий
		elseif MFI <= Prev_MFI*Delta and V(Index) > Prev_Vol*Delta then
			Prev_MFI = MFI
			Prev_Vol = V(Index)
			if Settings.Histogram=="off" then   return nil,nil,nil,1   else   return nil,nil,nil,MFI   end

		end
	else
		return nil,nil,nil,nil
	end
end

function BWMFI() --Bill Williams Market Facilitation I ("BWMFI")
	local it = {p=0, l=0}
	return function (I, Fsettings, ds)
		if I == 1 then
			it = {p=0, l=0}
		end
		if CandleExist(I,ds) then
			if I~=it.p then it={p=I, l=it.l+1} end
			return GetValueEX(it.p, DIFFERENCE, ds) / GetValueEX(it.p, VOLUME, ds)
		end
		return nil
	end
end


SMA,MMA,EMA,WMA,SMMA,VMA = "SMA","MMA","EMA","WMA","SMMA","VMA"
OPEN,HIGH,LOW,CLOSE,VOLUME,MEDIAN,TYPICAL,WEIGHTED,DIFFERENCE,ANY = "O","H","L","C","V","M","T","W","D","A"


function CandleExist(I,ds)
	return (type(C)=="function" and C(I)~=nil) or
		   (type(ds)=="table" and (ds[I]~=nil or (type(ds.Size)=="function" and (I>0) and (I<=ds:Size()))))
end

function Squeeze(I,P)
	return math.fmod(I-1,P+1)
end

function ConvertValue(T,...)
	local function r(V, R) 
		if R and string.upper(R)== "ON" then R=0 end
		if V and tonumber(R) then
			if V >= 0 then return math.floor(V * 10^R + 0.5) / 10^R
			else return math.ceil(V * 10^R - 0.5) / 10^R end
		else return V end
	end
	if arg.n > 0 then
		for i = 1, arg.n do
			arg[i]=arg[i] and r(arg[i] * ((T and T.Multiply) or 1), (T and T.Round) or "off")
		end
		return unpack(arg)
	else
		return nil
	end
end


function GetValueEX(I,VT,ds) 
	
	VT=(VT and string.upper(string.sub(VT,1,1))) or ANY
	
	if VT == OPEN then				--Open
		return (O and O(I)) or (ds and ds:O(I))
	elseif VT == HIGH then 			--High
		return (H and H(I)) or (ds and ds:H(I))
	elseif VT == LOW then			--Low
		return (L and L(I)) or (ds and ds:L(I))
	elseif VT == CLOSE then			--Close
		return (C and C(I)) or (ds and ds:C(I))
	elseif VT == VOLUME then		--Volume
		return (V and V(I)) or (ds and ds:V(I)) 
	elseif VT == MEDIAN then		--Median
		return ((GetValueEX(I,HIGH,ds) + GetValueEX(I,LOW,ds)) / 2)
	elseif VT == TYPICAL then		--Typical
		return ((GetValueEX(I,MEDIAN,ds) * 2 + GetValueEX(I,CLOSE,ds))/3)
	elseif VT == WEIGHTED then		--Weighted
		return ((GetValueEX(I,TYPICAL,ds) * 3 + GetValueEX(I,OPEN,ds))/4) 
	elseif VT == DIFFERENCE then	--Difference
		return (GetValueEX(I,HIGH,ds) - GetValueEX(I,LOW,ds))
	else							--Any
		return (ds and ds[I])
	end
	
	return nil
end
