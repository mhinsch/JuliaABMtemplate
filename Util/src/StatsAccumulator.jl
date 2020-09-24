#   Copyright (C) 2020 Martin Hinsch <hinsch.martin@gmail.com>
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <https://www.gnu.org/licenses/>.



module StatsAccumulator

export CountAcc, MVAcc, MVAcc2, add!, result, MaxMinAcc, AccList


### CountAcc

mutable struct CountAcc
	n :: Int
end

CountAcc() = CountAcc(0)

add!(acc :: CountAcc, cond) = cond ? acc.n += 1 : 0



### MVAcc

mutable struct MVAcc{T}
	sum :: T
	sum_sq :: T
	n :: Int
end

MVAcc{T}() where {T} = MVAcc(T(0), T(0), 0)

function add!(acc :: MVAcc{T}, v :: T) where {T}
	acc.sum += v
	acc.sum_sq += v*v
	acc.n += 1
end


result(acc :: MVAcc{T}) where {T} = acc.sum / acc.n, (acc.sum_sq - acc.sum*acc.sum/acc.n) / (acc.n - 1)



### MVAcc2

mutable struct MVAcc2{T}
	m :: T
	m2 :: T
	n :: Int
end

MVAcc2{T}() where T = MVAcc2(T(0), T(0), 0)

function add!(acc :: MVAcc2{T}, v :: T) where T
	delta = v - acc.m
	acc.n += 1
	delta_n = delta / acc.n
	acc.m += delta_n
	acc.m2 += delta * (delta - delta_n)
end

result(acc :: MVAcc2{T}) where {T} = acc.m, acc.m2 / acc.n



# MaxMinAcc

mutable struct MaxMinAcc{T}
	max :: T
	min :: T
end


MaxMinAcc{T}() where {T} = MaxMinAcc(typemin(T), typemax(T))


function add!(acc :: MaxMinAcc{T}, v :: T) where {T}
	acc.max = max(acc.max, v)
	acc.min = min(acc.min, v)
end



### AccList

struct AccList
	list :: Vector{Any}
end

AccList() = AccList([])

function add!(al :: AccList, v :: T) where {T}
	for a in al.list
		add!(a, v)
	end
end

end # module
