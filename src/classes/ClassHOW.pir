## $Id$

=head1 TITLE

ClassHOW - default metaclass

=head1 DESCRIPTION

This file for now actually just adds a method or two into P6metaclass. In the
long run, we probably need to subclass that, and make sure we have all of the
methods in here that are defined in the HOW API.

=head2 Methods on P6metaclass

=over

=item does(object, role)

Tests role membership.

=cut

.HLL 'parrot'
.namespace ['P6metaclass']
.sub 'does' :method
    .param pmc obj
    .param pmc type

    # Check if we have a Perl6Role - needs special handling.
    $I0 = isa type, 'Perl6Role'
    unless $I0 goto not_p6role
    .tailcall type.'ACCEPTS'(obj)
  not_p6role:
    $I0 = does obj, type
    .tailcall 'prefix:?'($I0)
.end


=item dispatch(obj, name, ...)

Dispatches to method of the given name on this class or one of its parents.

=cut

.sub 'dispatch' :method
    .param pmc obj
    .param string name
    .param pmc pos_args  :slurpy
    .param pmc name_args :slurpy :named

    # If it's a call on a role, need to pun it.
    if name == 'WHAT' goto no_pun
    $I0 = isa obj, 'Perl6Role'
    if $I0 goto pun_role_unselected
    $I0 = isa obj, 'Role'
    if $I0 goto pun_role
  no_pun:

    # Get MRO and an interator on it. Note that we need to handle calls on
    # protos a little specially, since parrotclass on them doesn't hand back
    # the class with the methods in it that we got from the proto.
    .local pmc parrotclass, mro, mro_it, cur_class, methods, candidate
    $I0 = isa obj, 'P6protoobject'
    if $I0 goto is_proto
    parrotclass = getattribute self, 'parrotclass'
    $I0 = isa obj, 'Whatever'
    if $I0 goto whatever_closure
    goto proto_done
  is_proto:
    parrotclass = class obj
  proto_done:
    mro = inspect parrotclass, 'all_parents'
    mro_it = iter mro

    # Iterate MRO and check its methods.
    .local int have_pmc_proxy
    have_pmc_proxy = 0
  mro_loop:
    unless mro_it goto mro_loop_end
    cur_class = shift mro_it
    $S0 = typeof cur_class
    if $S0 == 'PMCProxy' goto pmc_proxy
    methods = cur_class.'methods'()
    candidate = methods[name]
    if null candidate goto check_handles

    # If we're not in the current class, need a submethod check.
    eq_addr cur_class, parrotclass, submethod_check_done
    $I0 = isa candidate, 'Submethod'
    if $I0 goto check_handles
  submethod_check_done:

    # If it's a multi-method, check it has a variant we can call; if not,
    # keep looking along the MRO.
    $I0 = isa candidate, 'Perl6MultiSub'
    unless $I0 goto not_multi
    $P0 = candidate.'find_possible_candidates'(obj, pos_args :flat)
    unless $P0 goto mro_loop
  not_multi:

    # Got a method that we can call. XXX Set up exception handlers for if we
    # get a control expection for callsame or nextsame etc. Won't be able to
    # be tailcall then...
    .tailcall obj.candidate(pos_args :flat, name_args :flat :named)

  check_handles:
    # See if we have any complex handles to check.
    .local pmc handles_list, handles_it, handles_hash, attr
    .local string attrname
    handles_list = getprop '@!handles_dispatchers', cur_class
    if null handles_list goto mro_loop
    handles_it = iter handles_list
  handles_loop:
    unless handles_it goto handles_loop_end
    handles_hash = shift handles_it
    attrname = handles_hash['attrname']
    attr = getattribute obj, attrname
    if null attr goto handles_loop
    $P0 = handles_hash['match_against']

    # If we have a class or role, should get its method list and check if it
    # .can do that. Otherwise, smart-match against method name.
    $I0 = isa $P0, 'P6protoobject'
    if $I0 goto handles_proto
    $I0 = isa $P0, 'Perl6Role'
    if $I0 goto handles_role
    $I0 = isa $P0, 'Role'
    if $I0 goto handles_parrotrole
    $P1 = $P0.'ACCEPTS'(name)
    unless $P1 goto handles_loop
    goto do_handles_call

  handles_proto:
    $P1 = get_hll_global ['Perl6Object'], '$!P6META'
    $P0 = $P1.'get_parrotclass'($P0)
    goto handles_have_pc
  handles_role:
    $P0 = $P0.'!select'()
  handles_parrotrole:
  handles_have_pc:
    $P1 = $P0.'methods'()
    $I0 = exists $P1[name]
    unless $I0 goto handles_loop
  do_handles_call:
    $S0 = substr attrname, 0, 1
    if $S0 == '@' goto handles_on_array
    .tailcall attr.name(pos_args :flat, name_args :flat :named)
  handles_on_array:
    .local pmc handles_array_it
    handles_array_it = iter attr
  handles_array_it_loop:
    unless handles_array_it goto handles_array_it_loop_end
    $P0 = shift handles_array_it
    $I0 = $P0.'can'(name)
    unless $I0 goto handles_array_it_loop
    .tailcall $P0.name(pos_args :flat, name_args :flat :named)
  handles_array_it_loop_end:
    'die'("You used handles on attribute ", attrname, ", but nothing in the array can do method ", name)
  handles_loop_end:
    goto mro_loop

  pmc_proxy:
    # If we inherit from a PMC, we'll try doing the call directly later on.
    # XXX Odd issues if we try and do it by introspective methods...
    have_pmc_proxy = 1
    goto mro_loop

  mro_loop_end:
    # If we get here, we didn't find anything to dispatch to; error unless a
    # PMC can provide it.
    unless have_pmc_proxy goto error
    ($P0 :slurpy, $P1 :slurpy :named) = obj.name(pos_args :flat, name_args :flat :named)
    .return ($P0 :flat, $P1 :named :flat)

  error:
    # Error, unless invocant is a junction in which case we thread over it.
    $I0 = isa obj, 'Junction'
    if $I0 goto autothread_invocant
    $P0 = getattribute self, 'longname'
    'die'("Could not locate a method '", name, "' to invoke on class '", $P0, "'.")

  autothread_invocant:
    .local pmc values, values_it, res, res_list, type
    res_list = 'list'()
    values = obj.'eigenstates'()
    values_it = iter values
  values_it_loop:
    unless values_it goto values_it_loop_end
    $P0 = shift values_it
    $P1 = $P0.'HOW'()
    res = $P1.'dispatch'($P0, name, pos_args :flat, name_args :flat :named)
    push res_list, res
    goto values_it_loop
  values_it_loop_end:
    type = obj.'!type'()
    .tailcall '!MAKE_JUNCTION'(type, res_list)

  whatever_closure:
    if name == 'WHAT' goto proto_done # XXX And this is why .WHAT needs to become a macro...
    .tailcall '!MAKE_WHATEVER_CLOSURE'(name, pos_args, name_args)

  pun_role_unselected:
    obj = obj.'!select'()
  pun_role:
    obj = obj.'!pun'()
    .tailcall '!dispatch_method'(obj, name, pos_args :flat, name_args :flat :named)
.end


=item !MAKE_WHATEVER_CLOSURE

Creates whatever closures (*.foo => { $_.foo })

=cut

.sub '!MAKE_WHATEVER_CLOSURE'
    .param pmc name
    .param pmc pos_args
    .param pmc named_args
    .lex '$name', name
    .lex '$pos_args', pos_args
    .lex '$named_args', named_args
    .const 'Sub' $P0 = '!whatever_dispatch_helper'
    $P0 = newclosure $P0
    "!fixup_routine_type"($P0, "Block")
    .return ($P0)
.end
.sub '!whatever_dispatch_helper' :outer('!MAKE_WHATEVER_CLOSURE')
    .param pmc obj
    $P0 = find_lex '$name'
    $S0 = $P0
    $P1 = find_lex '$pos_args'
    $P2 = find_lex '$named_args'
    .tailcall obj.$S0($P1 :flat, $P2 :flat :named)
.end


=back

=cut

.HLL 'Perl6'

# Local Variables:
#   mode: pir
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4 ft=pir:
