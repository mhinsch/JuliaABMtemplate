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



module ParamUtils

export fields_as_args!, fields_as_cmdl,  override_pars_cmdl!, 
    pars_from_dict, par_from_dict, pars_to_dict 

using ArgParse
using REPL


"add all fields of a type to the command line syntax"
function fields_as_args!(arg_settings, t :: Type)
	fieldns = fieldnames(t)
	fieldts = fieldtypes(t)
        for (fn, ft) in zip(fieldns, fieldts)
		fdoc =  REPL.stripmd(REPL.fielddoc(t, fn))
		add_arg_table!(arg_settings, ["--" * String(fn)], Dict(:help => fdoc, :arg_type => ft))
	end
end


"generate command line arguments from an object"
function fields_as_cmdl(o, ignore = [])
	fields = fieldnames(typeof(o))
	res = ""
	for f in fields
		if string(f) in ignore
			continue
		end
		farg = replace(string(f), "_" => "-")
		value = replace(string(getfield(o, f)), " " => "")
		res *= " --" * farg * " " * value
	end

	res
end

"set fields in `par_objects` to values in `args`, if provided"
function override_pars_cmdl!(args, par_objects...)
    for pars in par_objects
        fields = fieldnames(typeof(pars))

        for f in fields
            if haskey(args, f) && args[f] != nothing
                setfield!(pars, f, args[f])
            end
        end
    end
    nothing
end


"convert value to type T"
as_type(::Type{T}, value) where{T} = value
as_type(::Type{T}, value::AbstractString) where {T} = parse(T, value)
# matrizes come back as [ "1 2 ; 3 4" ]
as_type(::Type{Array{T, 2}}, value::Vector{String}) where {T<:Number} = 
    parse(Array{T, 2}, value)
as_type(::Type{String}, value::AbstractString) = value

# For some reason Julia can *write* Rational, but not read it...
"parse Rational from an AbstractString"
function Base.parse(::Type{Rational{T}}, s::AbstractString) where {T}
    nums = split(s, "//")
    Rational{T}(parse(T, nums[1]), parse(T, nums[2]))
end

function ArgParse.parse_item(::Type{Vector{T}}, s::AbstractString) where {T}
    parse(Vector{T}, s)
end

"parse arrays of parseable types"
function Base.parse(::Type{T}, s::AbstractString) where {T<:AbstractArray}
	s1 = replace(s, r"[\[\]]"=>"")
	s2 = replace(s1, ','=>' ')
	s3 = split(s2)
	parse.(eltype(T), s3)
end

function Base.parse(::Type{Array{T, 2}}, value::Vector{String}) where {T<:Number}
    # matrizes come back as [ "1 2 ; 3 4" ]
    str = value[1]
    lines = split(str, ";")

    data = T[]

    for line in lines
        for el in split(line)
            push!(data, parse(T, el))
        end
    end

    # transform into matrix
    # there's probably an easier way, but this works and it's used only once
    # per simulation run anyway
    reshape(data, :, length(lines)) |> permutedims
end

# This is effectively a setfield replacement that allows for type coercion.
# We need this, as the representation of some built-in types (e.g. Rational)
# is understood as generic String by YAML, so we can't simply assign these fields when
# reading a YAML file. setValue pipes the assignment through asValue which converts
# a value of type A to type B (the field type in this case), but defaults to identity.
# We simply overload asValue for A==AbstractString and any B that is not recognised
# by YAML.
"set value of a struct's field while allowing for type coercion overloads"
set_value!(str, fname, value) = setfield!(str, fname, 
                                         as_type(fieldtype(typeof(str), fname), value))


"Read a parameter object `par` stored as `name` in dict `dict`."
function par_from_dict(dict, par, name; require_all_fields = true)
    # type not in file, so don't do anything
    if !haskey(dict, name)
        return par
    end

    pdict = dict[name]

    ptype = typeof(par)
    for f in fieldnames(ptype)
        if !haskey(pdict, f)
            if require_all_fields
                # all fields have to be set (or none)
                error("Field $f required in parameter $(name)!")
            else
                # ignore
                continue
            end
        end

        # use setValue, so that e.g. Rational can be converted from String
        set_value!(par, f, pdict[f])
    end

    par
end

#"Create objects from dict `dict`. Expects pairs of `type => name` in `partypes`. "
#function pars_from_dict(dict, partypes; require_all_fields = true)
#    [ par_from_dict(dict, typ(), name; require_all_fields) for (typ, name) in partypes ]
#end


"Create objects from dict `dict`. Returns a tuple of objects of the types given by `partypes`. "
function pars_from_dict(dict, partypes...; require_all_fields = true)
    ret_type = Tuple{partypes...}
    ret_type([ par_from_dict(dict, typ(), nameof(typ); require_all_fields) 
              for typ in partypes ])
end


"generate dict from `parameters`"
function pars_to_dict(parameters...; DType = Dict)
    dict = DType{Symbol, Any}()

    for par in parameters
        ptype = typeof(par)
        pdict = DType{Symbol, Any}()
        for n in fieldnames(ptype)
            pdict[n] = getfield(par, n)
        end

        dict[nameof(ptype)] = pdict
    end

    dict
end


end
