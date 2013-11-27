module PLY
	export rule, lexer, parser, parse, parserule, skip, lineno, set_lineno, lexpos, lexspan,
		token, skip

	import Base: getindex, setindex!, length, get, keys, values, isempty, show, error

	using PyCall

	@pyimport ply.lex as lex
	@pyimport ply.yacc as yacc

	const AttrDict = pyimport("attrdict")["AttrDict"]

	
	const vars = pyeval("vars", PyObject)
	const str = pyeval("str", PyObject)
	const funfactory = pyeval("lambda y: lambda x: y(x)", PyObject)


	# YaccProduction wrapper type
	type YaccProduction
		t::PyObject
	end

	getindex(p::YaccProduction, i::Int) = p.t[:__getitem__](i-1)
	getindex(p::YaccProduction, r::Range) = p.t[:__getslice__](r.start-1, r.start-1+r.len)
	setindex!(p::YaccProduction, value, i::Int) = p.t[:__setitem__](i-1, value)
	length(p::YaccProduction) = p.t[:__len__]()
	lineno(p::YaccProduction, n::Int) = p.t[:lineno](n)
	set_lineno(p::YaccProduction, n::Int, lineno::Int) = p.t[:set_lineno](n, lineno)
	setlineno = set_lineno
	linespan(p::YaccProduction, n::Int) = tuple(p.t[:linespan](n))
	lexpos(p::YaccProduction, n::Int) = p.t[:lexpos](n)
	lexspan(p::YaccProduction, n::Int) = p.t[:lexspan](n)
	error(p::YaccProduction) = p.t[:error]()


	# Wrapper type that enables field access by string index
	abstract PyObjectDictWrapper<:Associative{String,Any}

	getindex(tok::PyObjectDictWrapper, key::String) = tok.o[symbol(key)]
	setindex!(tok::PyObjectDictWrapper, value, key::String) = tok.o[symbol(key)] = value
	get(tok::PyObjectDictWrapper, key::String) = getindex(tok, key)
	function get(tok::PyObjectDictWrapper, key::String, default)
		skey = symbol(key)
		if haskey(tok.o, skey)
			return getindex(tok, key)
		else
			return default
		end
	end
	haskey(tok::PyObjectDictWrapper, key::String) = haskey(pycall(vars, PyAny, tok.o), key)
	keys(tok::PyObjectDictWrapper) = keys(pycall(vars, PyAny, tok.o))
	values(tok::PyObjectDictWrapper) = values(pycall(vars, PyAny, tok.o))
	isempty(tok::PyObjectDictWrapper) = isempty(pycall(vars, PyAny, tok.o))
	show(io::IO, tok::PyObjectDictWrapper) = show(io, pycall(str, PyAny, tok.o))


	# LexToken wrapper type
	type LexToken<:PyObjectDictWrapper
		o::PyObject
	end


	# Lexer wrapper type
	type Lexer<:PyObjectDictWrapper
		o::PyObject
	end

	token(lex::Lexer) = LexToken(lex.o[:token]())
	skip(lex::Lexer, n::Int) = lex.o[:skip](n)


	function rule(fn::Function)
		function wrapper(x)
			ret = fn(LexToken(x), Lexer(x[:lexer]))
			if isa(ret, LexToken)
				return ret.o
			else
				return ret
			end
		end
		return pycall(funfactory, PyObject, wrapper)
	end

	function rule(fn::Function, pattern::String)
		rule_func = rule(fn)
		rule_func[:__doc__] = pattern
		return rule_func
	end

	function parserule(fn::Function)
		return pycall(funfactory, PyObject, (x)->fn(YaccProduction(x)))
	end

	function parserule(fn::Function, pattern::String)
		rule_func = parserule(fn)
		rule_func[:__doc__] = pattern
		return rule_func
	end

	function lexer(tokrules::Dict; kwargs...)
		return lex.lex(pycall(AttrDict, PyObject, tokrules); kwargs...)
	end

	function parser(parserules::Dict; kwargs...)
		push!(kwargs, (:module, pycall(AttrDict, PyObject, parserules)))
		return pywrap(yacc.yacc(;start="statement", kwargs...))
	end

	function parse(parser, lexer, string; kwargs...)
		return parser.parse(string; lexer=lexer, kwargs...)
	end
end