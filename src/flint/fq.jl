###############################################################################
#
#   fq.jl : Flint finite fields
#
###############################################################################

export FlintFiniteField, characteristic, order, fq, FqFiniteField, frobenius,
       pth_root, trace, norm

###############################################################################
#
#   Type and parent object methods
#
###############################################################################

parent_type(::Type{fq}) = FqFiniteField

elem_type(::Type{FqFiniteField}) = fq

doc"""
    base_ring(a::FqFiniteField)
> Returns `Union{}` as this field is not dependent on another field.
"""
base_ring(a::FqFiniteField) = Union{}

doc"""
    base_ring(a::fq)
> Returns `Union{}` as this field is not dependent on another field.
"""
base_ring(a::fq) = Union{}

doc"""
    parent(a::fq)
> Returns the parent of the given finite field element.
"""
parent(a::fq) = a.parent

isdomain_type(::Type{fq}) = true

function check_parent(a::fq, b::fq)
   a.parent != b.parent && error("Operations on distinct finite fields not supported")
end

###############################################################################
#
#   Basic manipulation
#
###############################################################################

function Base.hash(a::fq, h::UInt)
   b = 0xb310fb6ea97e1f1a%UInt
   for i in 1:degree(parent(a)) + 1
      b = xor(b, xor(hash(coeff(a, i), h), h))
      b = (b << 1) | (b >> (sizeof(Int)*8 - 1))
   end
   return b
end

doc"""
    coeff(x::fq, n::Int)
> Return the degree $n$ coefficient of the polynomial representing the given
> finite field element.
"""
function coeff(x::fq, n::Int)
   n < 0 && throw(DomainError())
   z = fmpz()
   ccall((:fmpz_poly_get_coeff_fmpz, :libflint), Void,
               (Ref{fmpz}, Ref{fq}, Int), z, x, n)
   return z
end

doc"""
    zero(a::FqFiniteField)
> Return the additive identity, zero, in the given finite field.
"""
function zero(a::FqFiniteField)
   d = a()
   ccall((:fq_zero, :libflint), Void, (Ref{fq}, Ref{FqFiniteField}), d, a)
   return d
end

doc"""
    one(a::FqFiniteField)
> Return the multiplicative identity, one, in the given finite field.
"""
function one(a::FqFiniteField)
   d = a()
   ccall((:fq_one, :libflint), Void, (Ref{fq}, Ref{FqFiniteField}), d, a)
   return d
end

doc"""
    gen(a::FqFiniteField)
> Return the generator of the finite field. Note that this is only guaranteed
> to be a multiplicative generator if the finite field is generated by a
> Conway polynomial automatically.
"""
function gen(a::FqFiniteField)
   d = a()
   ccall((:fq_gen, :libflint), Void, (Ref{fq}, Ref{FqFiniteField}), d, a)
   return d
end

doc"""
    iszero(a::fq)
> Return `true` if the given finite field element is zero, otherwise return
> `false`.
"""
iszero(a::fq) = ccall((:fq_is_zero, :libflint), Bool,
                     (Ref{fq}, Ref{FqFiniteField}), a, a.parent)

doc"""
    isone(a::fq)
> Return `true` if the given finite field element is one, otherwise return
> `false`.
"""
isone(a::fq) = ccall((:fq_is_one, :libflint), Bool,
                    (Ref{fq}, Ref{FqFiniteField}), a, a.parent)

doc"""
    isgen(a::fq)
> Return `true` if the given finite field element is the generator of the
> finite field, otherwise return `false`.
"""
isgen(a::fq) = a == gen(parent(a))

doc"""
    isunit(a::fq)
> Return `true` if the given finite field element is invertible, i.e. nonzero,
> otherwise return `false`.
"""
isunit(a::fq) = ccall((:fq_is_invertible, :libflint), Bool,
                     (Ref{fq}, Ref{FqFiniteField}), a, a.parent)

doc"""
    characteristic(a::FqFiniteField)
> Return the characteristic of the given finite field.
"""
function characteristic(a::FqFiniteField)
   d = fmpz()
   ccall((:__fq_ctx_prime, :libflint), Void,
         (Ref{fmpz}, Ref{FqFiniteField}), d, a)
   return d
end

doc"""
    order(a::FqFiniteField)
> Return the order, i.e. the number of elements in, the given finite field.
"""
function order(a::FqFiniteField)
   d = fmpz()
   ccall((:fq_ctx_order, :libflint), Void,
         (Ref{fmpz}, Ref{FqFiniteField}), d, a)
   return d
end

doc"""
    degree(a::FqFiniteField)
> Return the degree of the given finite field.
"""
function degree(a::FqFiniteField)
   return ccall((:fq_ctx_degree, :libflint), Int, (Ref{FqFiniteField},), a)
end

function deepcopy_internal(d::fq, dict::ObjectIdDict)
   z = fq(parent(d), d)
   return z
end

###############################################################################
#
#   Canonicalisation
#
###############################################################################

canonical_unit(x::fq) = x

###############################################################################
#
#   AbstractString I/O
#
###############################################################################

function show(io::IO, x::fq)
   cstr = ccall((:fq_get_str_pretty, :libflint), Ptr{UInt8},
                (Ref{fq}, Ref{FqFiniteField}), x, x.parent)

   print(io, unsafe_string(cstr))

   ccall((:flint_free, :libflint), Void, (Ptr{UInt8},), cstr)
end

function show(io::IO, a::FqFiniteField)
   print(io, "Finite field of degree ", degree(a))
   print(io, " over F_", characteristic(a))
end

needs_parentheses(x::fq) = x.length > 1

isnegative(x::fq) = false

show_minus_one(::Type{fq}) = true

###############################################################################
#
#   Unary operations
#
###############################################################################

function -(x::fq)
   z = parent(x)()
   ccall((:fq_neg, :libflint), Void,
         (Ref{fq}, Ref{fq}, Ref{FqFiniteField}), z, x, x.parent)
   return z
end

###############################################################################
#
#   Binary operations
#
###############################################################################

function +(x::fq, y::fq)
   check_parent(x, y)
   z = parent(y)()
   ccall((:fq_add, :libflint), Void,
        (Ref{fq}, Ref{fq}, Ref{fq}, Ref{FqFiniteField}), z, x, y, y.parent)
   return z
end

function -(x::fq, y::fq)
   check_parent(x, y)
   z = parent(y)()
   ccall((:fq_sub, :libflint), Void,
        (Ref{fq}, Ref{fq}, Ref{fq}, Ref{FqFiniteField}), z, x, y, y.parent)
   return z
end

function *(x::fq, y::fq)
   check_parent(x, y)
   z = parent(y)()
   ccall((:fq_mul, :libflint), Void,
        (Ref{fq}, Ref{fq}, Ref{fq}, Ref{FqFiniteField}), z, x, y, y.parent)
   return z
end

###############################################################################
#
#   Ad hoc binary operators
#
###############################################################################

function *(x::Int, y::fq)
   z = parent(y)()
   ccall((:fq_mul_si, :libflint), Void,
         (Ref{fq}, Ref{fq}, Int, Ref{FqFiniteField}), z, y, x, y.parent)
   return z
end

*(x::Integer, y::fq) = fmpz(x)*y

*(x::fq, y::Integer) = y*x

function *(x::fmpz, y::fq)
   z = parent(y)()
   ccall((:fq_mul_fmpz, :libflint), Void,
         (Ref{fq}, Ref{fq}, Ref{fmpz}, Ref{FqFiniteField}),
                                            z, y, x, y.parent)
   return z
end

*(x::fq, y::fmpz) = y*x

+(x::fq, y::Integer) = x + parent(x)(y)

+(x::Integer, y::fq) = y + x

+(x::fq, y::fmpz) = x + parent(x)(y)

+(x::fmpz, y::fq) = y + x

-(x::fq, y::Integer) = x - parent(x)(y)

-(x::Integer, y::fq) = parent(y)(x) - y

-(x::fq, y::fmpz) = x - parent(x)(y)

-(x::fmpz, y::fq) = parent(y)(x) - y

###############################################################################
#
#   Powering
#
###############################################################################

function ^(x::fq, y::Int)
   if y < 0
      x = inv(x)
      y = -y
   end
   z = parent(x)()
   ccall((:fq_pow_ui, :libflint), Void,
         (Ref{fq}, Ref{fq}, Int, Ref{FqFiniteField}), z, x, y, x.parent)
   return z
end

function ^(x::fq, y::fmpz)
   if y < 0
      x = inv(x)
      y = -y
   end
   z = parent(x)()
   ccall((:fq_pow, :libflint), Void,
         (Ref{fq}, Ref{fq}, Ref{fmpz}, Ref{FqFiniteField}),
                                            z, x, y, x.parent)
   return z
end

###############################################################################
#
#   Comparison
#
###############################################################################

function ==(x::fq, y::fq)
   check_parent(x, y)
   ccall((:fq_equal, :libflint), Bool,
         (Ref{fq}, Ref{fq}, Ref{FqFiniteField}), x, y, y.parent)
end

###############################################################################
#
#   Ad hoc comparison
#
###############################################################################

==(x::fq, y::Integer) = x == parent(x)(y)

==(x::fq, y::fmpz) = x == parent(x)(y)

==(x::Integer, y::fq) = parent(y)(x) == y

==(x::fmpz, y::fq) = parent(y)(x) == y

###############################################################################
#
#   Exact division
#
###############################################################################

function divexact(x::fq, y::fq)
   check_parent(x, y)
   iszero(y) && throw(DivideError())
   z = parent(y)()
   ccall((:fq_div, :libflint), Void,
        (Ref{fq}, Ref{fq}, Ref{fq}, Ref{FqFiniteField}), z, x, y, y.parent)
   return z
end

function divides(a::fq, b::fq)
   iszero(b) && error("Division by zero in divides")
   return true, divexact(a, b)
end

###############################################################################
#
#   Ad hoc exact division
#
###############################################################################

divexact(x::fq, y::Integer) = divexact(x, parent(x)(y))

divexact(x::fq, y::fmpz) = divexact(x, parent(x)(y))

divexact(x::Integer, y::fq) = divexact(parent(y)(x), y)

divexact(x::fmpz, y::fq) = divexact(parent(y)(x), y)

###############################################################################
#
#   Inversion
#
###############################################################################

doc"""
    inv(x::fq)
> Return $x^{-1}$.
"""
function inv(x::fq)
   iszero(x) && throw(DivideError())
   z = parent(x)()
   ccall((:fq_inv, :libflint), Void,
         (Ref{fq}, Ref{fq}, Ref{FqFiniteField}), z, x, x.parent)
   return z
end

###############################################################################
#
#   Special functions
#
###############################################################################

doc"""
    pth_root(x::fq)
> Return the $p$-th root of $a$ in the finite field of characteristic $p$. This
> is the inverse operation to the Frobenius map $\sigma_p$.
"""
function pth_root(x::fq)
   z = parent(x)()
   ccall((:fq_pth_root, :libflint), Void,
         (Ref{fq}, Ref{fq}, Ref{FqFiniteField}), z, x, x.parent)
   return z
end

doc"""
    trace(x::fq)
> Return the trace of $a$. This is an element of $\F_p$, but the value returned
> is this value embedded in the original finite field.
"""
function trace(x::fq)
   z = fmpz()
   ccall((:fq_trace, :libflint), Void,
         (Ref{fmpz}, Ref{fq}, Ref{FqFiniteField}), z, x, x.parent)
   return parent(x)(z)
end

doc"""
    norm(x::fq)
> Return the norm of $a$. This is an element of $\F_p$, but the value returned
> is this value embedded in the original finite field.
"""
function norm(x::fq)
   z = fmpz()
   ccall((:fq_norm, :libflint), Void,
         (Ref{fmpz}, Ref{fq}, Ref{FqFiniteField}), z, x, x.parent)
   return parent(x)(z)
end

doc"""
    frobenius(x::fq, n = 1)
> Return the iterated Frobenius $\sigma_p^n(a)$ where $\sigma_p$ is the
> Frobenius map sending the element $a$ to $a^p$ in the finite field of
> characteristic $p$. By default the Frobenius map is applied $n = 1$ times if
> $n$ is not specified.
"""
function frobenius(x::fq, n = 1)
   z = parent(x)()
   ccall((:fq_frobenius, :libflint), Void,
         (Ref{fq}, Ref{fq}, Int, Ref{FqFiniteField}), z, x, n, x.parent)
   return z
end

###############################################################################
#
#   Unsafe functions
#
###############################################################################

function zero!(z::fq)
   ccall((:fq_zero, :libflint), Void,
        (Ref{fq}, Ref{FqFiniteField}), z, z.parent)
   return z
end

function mul!(z::fq, x::fq, y::fq)
   ccall((:fq_mul, :libflint), Void,
        (Ref{fq}, Ref{fq}, Ref{fq}, Ref{FqFiniteField}), z, x, y, y.parent)
   return z
end

function addeq!(z::fq, x::fq)
   ccall((:fq_add, :libflint), Void,
        (Ref{fq}, Ref{fq}, Ref{fq}, Ref{FqFiniteField}), z, z, x, x.parent)
   return z
end

function add!(z::fq, x::fq, y::fq)
   ccall((:fq_add, :libflint), Void,
        (Ref{fq}, Ref{fq}, Ref{fq}, Ref{FqFiniteField}), z, x, y, x.parent)
   return z
end

###############################################################################
#
#   Random functions
#
###############################################################################

function rand(K::FinField)
	p = characteristic(K)
	r = degree(K)
	alpha = gen(K)
	res = zero(K)
  range = BigInt(0):BigInt(p - 1)
	for i = 0 : (r-1)
		c = rand(range)
		res += c * alpha^i
	end
	return res
end

###############################################################################
#
#   Promotions
#
###############################################################################

promote_rule(::Type{fq}, ::Type{T}) where {T <: Integer} = fq

promote_rule(::Type{fq}, ::Type{fmpz}) = fq

###############################################################################
#
#   Parent object call overload
#
###############################################################################

function (a::FqFiniteField)()
   z = fq(a)
   return z
end

(a::FqFiniteField)(b::Integer) = a(fmpz(b))

function (a::FqFiniteField)(b::Int)
   z = fq(a, b)
   return z
end

function (a::FqFiniteField)(b::fmpz)
   z = fq(a, b)
   return z
end

function (a::FqFiniteField)(b::fq)
   parent(b) != a && error("Coercion between finite fields not implemented")
   return b
end

###############################################################################
#
#   FlintFiniteField constructor
#
###############################################################################

doc"""
    FlintFiniteField(char::fmpz, deg::Int, s::AbstractString)
> Returns a tuple $S, x$ consisting of a finite field parent object $S$ and
> generator $x$ for the finite field of the given characteristic and degree.
> The string $s$ is used to designate how the finite field generator will be
> printed. The characteristic must be prime. When a Conway polynomial is known,
> the field is generated using the Conway polynomial. Otherwise a random
> sparse, irreducible polynomial is used. The generator of the field is
> guaranteed to be a multiplicative generator only if the field is generated by
> a Conway polynomial. We require the degree to be positive.
"""
function FlintFiniteField(char::fmpz, deg::Int, s::AbstractString; cached = true)
   S = Symbol(s)
   parent_obj = FqFiniteField(char, deg, S, cached)
   return parent_obj, gen(parent_obj)
end

doc"""
    FlintFiniteField(char::Integer, deg::Int, s::AbstractString)
> Returns a tuple $S, x$ consisting of a finite field parent object $S$ and
> generator $x$ for the finite field of the given characteristic and degree.
> The string $s$ is used to designate how the finite field generator will be
> printed. The characteristic must be prime. When a Conway polynomial is known,
> the field is generated using the Conway polynomial. Otherwise a random
> sparse, irreducible polynomial is used. The generator of the field is
> guaranteed to be a multiplicative generator only if the field is generated by
> a Conway polynomial. We require the degree to be positive.
"""
function FlintFiniteField(char::Integer, deg::Int, s::AbstractString; cached = true)
   return FlintFiniteField(fmpz(char), deg, s; cached = cached)
end

doc"""
    FlintFiniteField(pol::fmpz_mod_poly, s::AbstractString)
> Returns a tuple $S, x$ consisting of a finite field parent object $S$ and
> generator $x$ for the finite field over $F_p$ defined by the given
> polynomial, i.e. $\mathbb{F}_p[t]/(pol)$. The characteristic is specified by
> the modulus of `pol`. The polynomial is required to be irreducible, but this
> is not checked. The string $s$ is used to designate how the finite field
> generator will be printed. The generator will not be multiplicative in
> general.
"""
function FlintFiniteField(pol::fmpz_mod_poly, s::AbstractString; cached = true)
   S = Symbol(s)
   parent_obj = FqFiniteField(pol, S, cached)

   return parent_obj, gen(parent_obj)
end
