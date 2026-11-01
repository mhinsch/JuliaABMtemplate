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



module Params2Args

export fields_as_args!, create_from_args, @create_from_args

using ArgParse
using REPL


"add all fields of a type as command line arguments"
function fields_as_args!(arg_settings, t :: Type)
	fields = fieldnames(t)
	for f in fields
		fdoc =  REPL.stripmd(REPL.fielddoc(t, f))
		add_arg_table!(arg_settings, ["--" * String(f)], Dict(:help => fdoc))
	end
end

"create object from command line arguments, using module mod as context"
function create_from_args(args, t :: Type, mod)
	par_expr = Expr(:call, t.name.name)

	fields = fieldnames(t)

	for key in eachindex(args)
		if args[key] == nothing || !(key in fields)
			continue
		end
		val = parse(fieldtype(t, key), args[key])
		push!(par_expr.args, Expr(:kw, key, val))
	end

	mod.eval(par_expr)
end

"create object from command line arguments in current module"
macro create_from_args(arguments, t)
	:(create_from_args($(esc(arguments)), $(esc(t)), $(__module__)))
end

end
