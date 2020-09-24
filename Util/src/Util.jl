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



module Util


export drop!, drop_at!, @set_to_max!, @update!, limit, valley, sigmoid,
	unf_delta, distance, parse, Pathfinding, StatsAccumulator, Observation


function Base.parse(t :: Type{T}, str) where {T<:Array}
	v = t()
	last = length(str)
	i = 1

	while i != nothing && i<=last
		f = findnext(",", str, i)
		if f==nothing && i<=last
			j = last
		else
			j = f[1]-1
		end

		println(i, ", ", j)

		if j != nothing
			push!(v, parse(eltype(t), SubString(str, i, j)))
		end
		i = j+2
	end

	v
end



function drop!(cont, elem)
	for i in eachindex(cont)
		if cont[i] == elem
			drop_at!(cont, i)
			return i
		end
	end

	# TODO convert into index type
	return 0
end


function drop_at!(cont, i)
	cont[i] = cont[end]
	pop!(cont)
end


macro set_to_max!(a, b)
	esc(:(a > b ? (b = a) : (a=b)))
end


macro update!(fun, args...)
   esc( :( ($(args...),) = $fun($(args...)) ) )
end


@inline function sigmoid(x, alpha, mid)
	c = mid/(1.0-mid)
	xa = x^alpha
	xa/(((1.0-x)*c)^alpha + xa)
end


# 0 at bottom, sigmoid to 1 on both sides, f(bottom +- steep) == 0.5
valley(x, bottom, steep, alpha=3) = 
	abs((x-bottom)^alpha) / (steep^alpha + abs((x-bottom)^alpha))

unf_delta(x) = rand() * 2.0 * x - x

limit(mi, v, ma) = min(ma, max(v, mi))


distance(x1, y1, x2, y2) = sqrt((x1-x2)^2 + (y1-y2)^2)


include("Pathfinding.jl")
include("StatsAccumulator.jl")
include("Observation.jl")

end
