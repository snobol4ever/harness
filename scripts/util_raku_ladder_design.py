#!/usr/bin/env python3
"""util_raku_ladder_design.py -- THE RAKU-TO-100 LADDER AND ROAST MAP, GENERATED FROM THE DATA (the cto, 2026-10-30, CEO-2044/2045/2046;
.github/ARCH-RAKU-TO-100.md section 3 is the rule this script applies, and the script is the rule's one executable form).

READS  the design row's frozen snapshot (every Roast program not PASS), results.tsv (the latest mode-3 note per program: the emitter's
       refusal names a construct), corpus/packages/raku/roast/TESTS.tsv (the constructs every Roast TAP test exercises, cut from Rakudo 09-27),
       corpus/tests/raku/config/LADDER.tsv (rung00..rung20, BUILT), corpus/tests/raku/config/CORE-NAMES.tsv (Raku's CORE:: symbols, written
       once from `raku -e` and read from the file after), src/runtime/rk_rakudo_method_names.inc (Rakudo's method names: the core-method filter).
WRITES corpus/tests/raku/config/LADDER.tsv (rung21.. appended, STATUS DECLARED or HELD; rung00..20 untouched),
       corpus/tests/raku/config/ROAST-RUNG-MAP.tsv (program TAB first-blocking rung TAB unblock rung TAB outcome TAB basis TAB construct),
       and prints the page's rung table (markdown) and the counts on stdout. --dry-run prints and writes nothing.
THE RULE: a construct is a LANGUAGE FEATURE when its family is kw, op, lit, quote, regex, twigil, var, meta, test, or a meth/call/type/word
       name Raku's CORE or Rakudo's method list knows (a test-local name places nothing); features are grouped into twenty families in
       dependency order (F01 literals .. F20 concurrency, held) and within a family ordered by the number of red programs that exercise them;
       each feature not covered by rung00..20 is one rung; a program's FIRST-BLOCKING rung is the lowest rung among its features and its
       UNBLOCK rung the highest; an emitter refusal that names a construct overrides the first block; a program with no feature row is placed
       by its chapter at the family's first rung. Every placement carries its basis column so a builder can see why.
"""
import collections, os, re, subprocess, sys
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SN = '/home/resources/postoffice/tasks/design-raku-to-100-every-roast-feature-on-a-complexity-ordered-rung-ladder-built-incrementally-ceo-2044.snapshot.tsv'
RESULTS = '/home/resources/progress/results.tsv'
TESTS = os.path.join(ROOT, 'corpus/packages/raku/roast/TESTS.tsv')
LADDER = os.path.join(ROOT, 'corpus/tests/raku/config/LADDER.tsv')
MAP = os.path.join(ROOT, 'corpus/tests/raku/config/ROAST-RUNG-MAP.tsv')
CORE = os.path.join(ROOT, 'corpus/tests/raku/config/CORE-NAMES.tsv')
METH = os.path.join(ROOT, 'SCRIP/src/runtime/rk_rakudo_method_names.inc')
DRY = '--dry-run' in sys.argv

FAMILIES = [
 ('F01', 'literals and values', 'bb_lit_scalar / bb_rk_coerce (new: numeric, string and boolean context of a value, one tag test in the box)'),
 ('F02', 'variables, containers and declarators', 'bb_rk_scalar (new: the Scalar container, = against :=, itemization, defaults) over bb_var and bb_assign_var'),
 ('F03', 'operators', 'bb_binop_arith / bb_binop_relop (existing) by operator class; bb_rk_hyper (new) for meta, hyper, reduce, X and Z; bb_rk_junction for the junction infixes'),
 ('F04', 'control flow', 'bb_gate (if, unless, with), bb_to (loops) and bb_rk_control (new: next, last, redo, succeed, proceed and return as control exceptions on the one protocol)'),
 ('F05', 'subs, signatures and dispatch', 'bb_call_fn / bb_call_value (existing) with bb_rk_sig (new: positional, named, slurpy, optional, defaults, type and where checks, captures) and bb_rk_dispatch (new: multi candidates and methods by a per-type table, never by name)'),
 ('F06', 'blocks, closures and topics', 'bb_rk_block (new: a block invocation with its topic, placeholders, LEAVE/KEEP/UNDO) over bb_proc_value'),
 ('F07', 'lists, arrays, hashes and sequences', 'bb_rk_iter (new: the one iterator box, pull-one over List, Range, Seq, gather, lazy) and bb_rk_aggr (new: index, slice, autoviv, elems, push and pop primitives) over bb_iterate and bb_suspend; the methods are SETTING Raku over them'),
 ('F08', 'strings and normalization', 'bb_rk_dispatch to rtx_rk_str_* (ASM leaves over the NFG and case tables); the methods are SETTING Raku over the leaves'),
 ('F09', 'numerics', 'bb_binop_arith with bb_rk_num (new: the Int, Rat, Num, Complex tower selected by tags) over rtx_rk_bigint and rtx_rk_rat (ASM leaves; bignum.c and rk_rat.c retire)'),
 ('F10', 'classes, roles, methods and the MOP', 'bb_rk_dispatch (new) with bb_create and bb_field_get (existing) and bb_rk_type (new: type checks, coercion, role composition, mixins); the MOP is SETTING Raku'),
 ('F11', 'exceptions, failures and the Test assertions', 'bb_rk_control (new) on ARCH-EXCEPTIONS-ONE-PROTOCOL (a raise returns, the box unwinds); CATCH and CONTROL are bb_rk_block arms; Test is SETTING Raku (R10)'),
 ('F12', 'smartmatch, junctions and boolean context', 'bb_rk_smartmatch (new: by the right operand kind, a kind switch box otherwise) and bb_rk_junction (new: autothreading as the box own alternation, collapse at boolean context)'),
 ('F13', 'regex, match objects and grammars', 'bb_match_rkrun / bb_match_rkcap / bb_match_rkland (existing) with the bb_match_* pattern family; rules are bb_call into pattern graphs; rx.c retires for Raku (R6)'),
 ('F14', 'types, coercions, natives, enums and subsets', 'bb_rk_type (new) and bb_rk_coerce; native cells are planner cell kinds (bb_rk_native: the typed cell forms of box_cell_shapes.tsv)'),
 ('F15', 'phasers and statement prefixes', 'bb_rk_phaser (new: ENTER, LEAVE, KEEP, UNDO, FIRST, NEXT, LAST on the block ports; BEGIN, CHECK, INIT, END at lowering and at the program ports)'),
 ('F16', 'IO, processes and the environment', 'bb_rk_dispatch to rtx_rk_io_* (ASM leaves over the syscalls); NOT-A-BOX: a syscall is a leaf; the IO::Path and IO::Handle methods are SETTING Raku over the leaves'),
 ('F17', 'packages, modules, pragmas, EVAL and pod', 'NOT-A-BOX: a use, no, need, require, unit, module or package directive is lowered at compile time and runs nothing; EVAL is the compile-at-run-time road (runtime_eval and planner_rt_plan, R11); pod is data (R2); bb_call_proc_staged for an EVAL result'),
 ('F18', 'dynamics, introspection and the call frame', 'bb_var_frame with rtx_rk_dynfind (ASM leaf walking the dynamic chain for $*X); .WHAT, .WHO, .HOW, .VAR, .DEFINITE are bb_rk_type reads; callframe and Backtrace read ARCH-GC section 13 chain'),
 ('F19', 'sets, bags and mixes', 'bb_rk_sets (new: the QuantHash family) over bb_rk_aggr; the set operators through bb_rk_hyper'),
 ('F20', 'concurrency (S17), HELD on Lon word', 'NOT-A-BOX: held; Promise, Supply, Channel, start, await, react, whenever, Lock, Proc::Async ride the thread runtime when Lon opens S17 (R11)'),
]
FAM_IDX = {f[0]: i for i, f in enumerate(FAMILIES)}

BUILT = set("""lit:int lit:str1 lit:str2 lit:interp lit:dec lit:num kw:my kw:say kw:print kw:sub kw:return kw:if kw:elsif kw:else kw:unless kw:while
 kw:until kw:loop kw:for kw:given kw:when kw:default kw:try kw:die kw:class kw:method kw:has kw:self kw:role kw:does kw:new kw:True kw:False kw:and kw:or kw:not
 kw:any kw:all kw:one kw:none kw:last kw:next kw:use
 op:+ op:- op:* op:/ op:% op:** op:~ op:x op:== op:!= op:< op:> op:<= op:>= op:eq op:ne op:lt op:gt op:le op:ge op:&& op:|| op:! op:? op:<=> op:cmp op:leg
 op:= op:=> op:-> op:.. op:++ op:-- op:+= op:-= op:*= op:~= op:| op:& op:^ op:, op:?? op:!! op:// op:.
 var:$ var:@ var:% var:$_ twigil:^ twigil:. twigil:!
 meth:elems meth:join meth:push meth:pop meth:shift meth:unshift meth:keys meth:values meth:kv meth:pairs meth:map meth:grep meth:first meth:sort meth:reduce
 meth:chars meth:uc meth:lc meth:substr meth:index meth:split meth:flip meth:trim meth:comb meth:say meth:print meth:new meth:Str meth:Int meth:Num meth:Bool meth:gist meth:raku meth:defined
 call:say call:print call:defined call:push call:pop call:shift call:unshift call:join call:split call:elems call:sort call:map call:grep call:first call:reduce call:die call:exit
 test:plan test:ok test:nok test:is test:isnt test:is-deeply test:isa-ok test:pass test:flunk test:diag test:done-testing test:skip test:todo test:subtest test:lives-ok test:dies-ok test:throws-like test:cmp-ok test:is-approx
 type:Int type:Str type:Num type:Bool type:Array type:Hash type:List type:Any type:Mu type:Test""".split())

STR_METHS = set("""chars codes comb contains starts-with ends-with substr substr-rw subst index rindex indices split words lines trim trim-leading trim-trailing uc lc tc tclc fc wordcase samecase samemark flip ord ords chr chrs chomp chop fmt sprintf printf encode decode utf8 NFC NFD NFKC NFKD uniname uninames uniprop uniprops unival univals unimatch uniparse parse-base parse-names succ pred match trans indent Str Stringy IO val Numeric Int Rat Num Real base polymod lc uc invert Version""".split())
STR_CALLS = set("chars comb substr index rindex indices split words lines trim trim-leading trim-trailing uc lc tc tclc fc wordcase samecase samemark flip ord ords chr chrs chomp chop sprintf printf uniname uninames uniprop uniprops unival univals unimatch uniparse parse-base parse-names val".split())
NUM_METHS = set("""abs floor ceiling round truncate sqrt exp log log2 log10 sin cos tan asin acos atan atan2 sinh cosh tanh asinh acosh atanh sec cosec cotan asec acosec acotan sech cosech cotanh asech acosech acotanh cis unpolar re im conj polar roots sign is-prime gcd lcm expmod nude numerator denominator narrow Rat FatRat Num Complex Int Real Numeric Bridge rand srand base msb lsb pred succ lcm gcd mod div sum min max minmax""".split())
NUM_CALLS = set("abs floor ceiling round truncate sqrt exp log log2 log10 sin cos tan asin acos atan atan2 sinh cosh tanh asinh acosh atanh sec cosec cotan asec acosec acotan sech cosech cotanh asech acosech acotanh cis unpolar roots sign is-prime expmod rand srand sum min max minmax lsb msb".split())
LIST_METHS = set("""elems end keys values kv pairs antipairs invert push pop shift unshift append prepend splice reverse rotate sort map grep first head tail skip flat eager lazy list List Array Hash Map Seq Slip Set Bag Mix cache iterator pull-one push-all push-exactly is-lazy join pick roll unique repeated squish classify categorize produce reduce sum min max minmax any all one none combinations permutations rotor batch pairup zip cross roundrobin toggle nodemap deepmap duckmap tree flatmap race hyper AT-POS AT-KEY EXISTS-POS EXISTS-KEY DELETE-POS DELETE-KEY ASSIGN-POS ASSIGN-KEY BIND-POS BIND-KEY STORE of default shape dims item Capture Supply total exists delete""".split())
LIST_CALLS = set("elems end keys values kv pairs antipairs push pop shift unshift append prepend splice reverse rotate sort map grep first head tail skip flat eager lazy list item cache join pick roll unique repeated squish classify categorize produce reduce zip cross roundrobin combinations permutations slip take gather infix:<,> hash array".split())
IO_METHS = set("""open close slurp spurt lines get getc read write print say put note eof flush seek tell nl-in nl-out encoding chmod chown e f d r w x s z l mkdir rmdir unlink rename copy move chdir dir absolute relative basename dirname extension parent child add resolve sibling volume cleanup is-absolute is-relative path IO modified accessed changed mode stat slurp-rest words comb canonpath splitdir catdir catpath catfile abs2rel rel2abs curdir updir devnull tmpdir rootdir splitpath join split is-absolute no-parent-or-current-test spawn shell run exitcode signal pid out err in stdout stderr stdin bind-stdout bind-stderr bind-stdin kill ready started""".split())
IO_CALLS = set("open close slurp spurt lines get getc prompt print say put note dir mkdir rmdir unlink rename copy move chdir chmod chown symlink link indir run shell exit sleep sleep-timer sleep-until signal".split())
PAIR_METHS = set("key value antipair freeze invert".split())
DATE_METHS = set("year month day hour minute second whole-second day-of-week day-of-year days-in-month is-leap-year later earlier truncated-to Date DateTime Instant Duration now posix timezone offset formatter yyyy-mm-dd hh-mm-ss week week-number week-year weekday-of-month daycount".split())
ROUTINE_METHS = set("name arity count signature of returns params positional named slurpy optional type constraints sub_signature package multi dispatchees candidates cando wrap unwrap is_dispatcher yada".split())
MOP_METHS = set("""WHAT WHO HOW WHICH WHERE VAR DEFINITE isa does can clone bless new CREATE BUILD TWEAK BUILDALL ACCEPTS perl raku gist Str name methods attributes mro parents roles roles_to_compose add_method add_attribute compose find_method lookup find_method_qualified is_composed shortname package type_check archetypes candidates cando signature arity count of returns wrap unwrap callsame callwith nextsame nextwith nextcallee lastcall samewith FALLBACK dispatcher is_dispatcher derive_dispatcher invoke_dispatcher enum_values enum_value_list enum_from_value key value pair""".split())
EXC_METHS = set("message backtrace throw rethrow resume exception handled Failure fail payload backtrace-is-in-core gist Str sink defined so not".split())
TEST_EXC = set("throws-like dies-ok lives-ok fails-like eval-dies-ok eval-lives-ok like unlike does-ok can-ok isa-ok use-ok".split())
CONC_KW = set("start await react whenever supply emit done lock atomic-add-fetch atomic-assign atomic-fetch cas full-barrier".split())
CONC_TYPES = set("Promise Supply Supplier Channel Lock Semaphore Thread Scheduler ThreadPoolScheduler CurrentThreadScheduler Tap Cancellation Awaitable Awaiter HyperSeq RaceSeq Proc::Async atomicint".split())
SET_TYPES = set("Set SetHash Bag BagHash Mix MixHash Setty Baggy Mixy QuantHash".split())
SET_OPS = set("(elem) (cont) (|) (&) (-) (^) (<) (<=) (>) (>=) (.) (+) (==) (<+) (>+) ∈ ∉ ∊ ∋ ∌ ∍ ∪ ∩ ∖ ⊂ ⊃ ⊄ ⊅ ⊆ ⊇ ⊈ ⊉ ⊍ ⊎ ⊖ ≼ ≽".split())
REGEX_TYPES = set("Match Regex Grammar Cursor".split())
IO_TYPES = set("IO IO::Path IO::Handle IO::Spec IO::Spec::Unix IO::Spec::Win32 IO::Spec::Cygwin IO::Spec::QNX IO::Special IO::Pipe IO::Socket IO::Socket::INET IO::Socket::Async IO::Notification IO::CatHandle IO::ArgFiles Proc Proc::Async".split())
EXC_TYPES_PREFIX = ('X::', 'Exception', 'Failure', 'Backtrace', 'CX::')
NUM_TYPES = set("Int Num Rat FatRat Complex Numeric Real Rational Int:D UInt Order Less More Same".split())
STR_TYPES = set("Str Stringy Cool Blob Buf utf8 utf16 utf32 Uni NFC NFD NFKC NFKD Encoding blob8 buf8 Allomorph IntStr NumStr RatStr ComplexStr StrDistance Collation".split())
LIST_TYPES = set("List Array Hash Map Pair Range Seq Slip Iterable Iterator Positional Associative PositionalBindFailover IterationBuffer IterationEnd Capture Sequence Array::Shaped array".split())
MOP_TYPES = set("Mu Any Attribute Metamodel Metamodel::ClassHOW Metamodel::RoleHOW ClassHOW Method Submethod Sub Routine Code Block Callable Signature Parameter Macro Scalar Proxy Variable ObjAt ValueObjAt Label Enumeration".split())
INTRO_TYPES = set("CallFrame Stash PseudoStash Compiler VM Kernel Distro Perl Raku Rakudo Systemic Version Date DateTime Instant Duration Dateish".split())
POD_WORDS = set("pod begin end for head1 head2 head3 item defn table code comment para config".split())
TRAIT_WORDS = set("rw copy raw readonly default dynamic required export is does returns of handles hides trusts will repr native cached pure".split())
NATIVE_WORDS = set("int int8 int16 int32 int64 uint uint8 uint16 uint32 uint64 num num32 num64 str byte".split())
ADVERB_WORDS = set("exists delete kv nth sigspace ratchet ignorecase ignoremark".split())
OPDEF_WORDS = set("infix prefix postfix circumfix postcircumfix term trait_mod".split())
CORE_WORDS_FAM = {}
for w in POD_WORDS: CORE_WORDS_FAM[w] = 'F17'
for w in TRAIT_WORDS: CORE_WORDS_FAM[w] = 'F05'
for w in NATIVE_WORDS: CORE_WORDS_FAM[w] = 'F14'
for w in ADVERB_WORDS: CORE_WORDS_FAM[w] = 'F07'
for w in OPDEF_WORDS: CORE_WORDS_FAM[w] = 'F05'
KW_FAM = {}
for w in "True False Nil Inf NaN pi e tau i".split(): KW_FAM[w] = 'F01'
for w in "my our state constant has anon let temp let".split(): KW_FAM[w] = 'F02'
for w in "and or not xor andthen orelse notandthen div mod gcd lcm x xx eq ne lt gt le ge cmp leg before after min max o but".split(): KW_FAM[w] = 'F03'
for w in "if elsif else unless with without while until loop repeat for given when default last next redo succeed proceed do once".split(): KW_FAM[w] = 'F04'
for w in "sub multi proto only return returns callsame callwith nextsame nextwith samewith nextcallee is where of export".split(): KW_FAM[w] = 'F05'
for w in "gather take lazy eager hyper race slip".split(): KW_FAM[w] = 'F07'
for w in "class role method submethod self new BUILD TWEAK handles hides trusts also augment supersede does".split(): KW_FAM[w] = 'F10'
for w in "try die fail warn CATCH CONTROL throw rethrow resume".split(): KW_FAM[w] = 'F11'
for w in "any all one none so".split(): KW_FAM[w] = 'F12'
for w in "grammar token rule regex make made".split(): KW_FAM[w] = 'F13'
for w in "enum subset Any Mu Cool".split(): KW_FAM[w] = 'F14'
for w in "BEGIN CHECK INIT END ENTER LEAVE KEEP UNDO FIRST NEXT LAST PRE POST QUIT CLOSE DOC quietly sink".split(): KW_FAM[w] = 'F15'
for w in "run shell QX".split(): KW_FAM[w] = 'F16'
for w in "use no need require import module package unit EVAL EVALFILE".split(): KW_FAM[w] = 'F17'
for w in "callframe caller".split(): KW_FAM[w] = 'F18'
for w in CONC_KW: KW_FAM[w] = 'F20'
OP_FAM = {}
for o in "~~ !~~".split(): OP_FAM[o] = 'F12'
for o in SET_OPS: OP_FAM[o] = 'F19'
for o in ".^ .? .+ .* .&".split(): OP_FAM[o] = 'F10'
for o in ":: ::?".split(): OP_FAM[o] = 'F17'
for o in "X Z ... ...^ ^... xx".split(): OP_FAM[o] = 'F07'
for o in "= := =:= ::=".split(): OP_FAM[o] = 'F02'
for o in "-> <->".split(): OP_FAM[o] = 'F06'

FAM_BOX = {'F01': 'bb_lit_scalar; bb_rk_coerce for a value in context', 'F02': 'bb_rk_scalar over bb_var / bb_assign_var', 'F03': 'bb_binop_arith / bb_binop_relop; bb_rk_hyper for a meta or hyper form',
 'F04': 'bb_gate / bb_to; bb_rk_control for a transfer', 'F05': 'bb_call_fn with bb_rk_sig; bb_rk_dispatch for a multi', 'F06': 'bb_rk_block over bb_proc_value', 'F07': 'bb_rk_iter / bb_rk_aggr; the method body is SETTING Raku',
 'F08': 'bb_rk_dispatch to rtx_rk_str_* (ASM leaf); the method body is SETTING Raku', 'F09': 'bb_binop_arith with bb_rk_num; rtx_rk_bigint / rtx_rk_rat (ASM leaves)', 'F10': 'bb_rk_dispatch with bb_rk_type; bb_create / bb_field_get; the MOP is SETTING Raku',
 'F11': 'bb_rk_control on the one exceptions protocol; CATCH is a bb_rk_block arm; Test is SETTING Raku', 'F12': 'bb_rk_smartmatch / bb_rk_junction', 'F13': 'bb_match_rkrun / bb_match_rkcap / bb_match_rkland and the bb_match_* family',
 'F14': 'bb_rk_type / bb_rk_coerce; bb_rk_native cells', 'F15': 'bb_rk_phaser on the block ports', 'F16': 'bb_rk_dispatch to rtx_rk_io_* (ASM leaf over a syscall; the syscall itself is NOT-A-BOX: a kernel entry)', 'F17': 'NOT-A-BOX: lowered at compile time (a directive) or the compile-at-run-time road (EVAL) or data (pod)',
 'F18': 'bb_var_frame with rtx_rk_dynfind (ASM leaf); bb_rk_type for the reads', 'F19': 'bb_rk_sets over bb_rk_aggr; bb_rk_hyper for the operators', 'F20': 'NOT-A-BOX: HELD on Lon word (S17 rides the thread runtime when opened)'}
def box_of(c, fam):
    if c in ('kw:EVAL', 'kw:EVALFILE', 'meth:EVAL', 'call:EVAL'): return 'NOT-A-BOX: the compile-at-run-time road (runtime_eval, planner_rt_plan), one road for every language (R11)'
    if c == 'word:pod' or c == 'twigil:=': return 'NOT-A-BOX: pod is data built by the lowerer as $=pod (R2); no box runs'
    if c in ('kw:use', 'kw:no', 'kw:need', 'kw:require', 'kw:import', 'kw:unit', 'kw:module', 'kw:package', 'call:lib', 'op:::'): return 'NOT-A-BOX: a loader or scope directive, lowered at compile time; nothing runs at the site'
    if c == 'twigil:?': return 'NOT-A-BOX: a compile-time constant the lowerer substitutes ($?FILE, $?LINE, $?PACKAGE, $?BITS)'
    if c in ('kw:gather', 'kw:take', 'call:take', 'kw:lazy', 'meth:is-lazy', 'meth:iterator', 'meth:pull-one', 'op:...', 'op:...^', 'op:^...'): return 'bb_suspend / bb_rk_iter: the generator road (R5), take is a gamma-SUSPEND, the consumer beta resumes it'
    if c.startswith('regex:') or c in ('kw:token', 'kw:rule', 'kw:regex', 'kw:grammar', 'meth:parse', 'meth:subparse', 'meth:parsefile', 'meth:match', 'meth:subst'): return 'bb_match_rkrun / bb_match_rkcap / bb_match_rkland and the bb_match_* pattern family (R6); a rule is bb_call into a pattern graph'
    if c in ('op:~~', 'op:!~~', 'kw:when'): return 'bb_rk_smartmatch by the right operand kind'
    if c in ('kw:class', 'kw:role', 'kw:method', 'kw:submethod', 'kw:has', 'kw:does', 'kw:self', 'kw:bless', 'kw:new', 'kw:but', 'op:.^', 'op:.?', 'op:.*', 'op:.+', 'op:.&'): return 'bb_rk_dispatch with bb_rk_type over bb_create / bb_field_get; the MOP is SETTING Raku'
    if c in ('kw:multi', 'kw:proto', 'kw:only', 'kw:callsame', 'kw:callwith', 'kw:nextsame', 'kw:nextwith', 'kw:samewith', 'kw:nextcallee', 'call:callsame', 'call:callwith', 'call:nextsame', 'call:nextwith', 'call:samewith', 'call:nextcallee', 'call:lastcall'): return 'bb_rk_dispatch: candidates sorted at lowering, bound at the call (R8)'
    if c in ('kw:try', 'kw:die', 'kw:fail', 'kw:CATCH', 'kw:CONTROL', 'kw:warn', 'call:die', 'call:fail', 'call:warn', 'meth:throw', 'meth:rethrow', 'meth:resume', 'kw:return', 'kw:last', 'kw:next', 'kw:redo', 'kw:succeed', 'kw:proceed', 'call:proceed', 'call:succeed', 'call:leave', 'call:return-rw'): return 'bb_rk_control on ARCH-EXCEPTIONS-ONE-PROTOCOL (a raise returns and the box unwinds)'
    if c.startswith('test:'): return 'SETTING Raku (Test.rakumod, R10) over bb_rk_control and bb_call_fn'
    if c.startswith('type:X::') or c.startswith('type:CX::') or c in ('type:Exception', 'type:Failure', 'type:Backtrace'): return 'SETTING Raku (the exception class) raised through bb_rk_control; bb_rk_type for the type check'
    if fam == 'F16' and (c.startswith('call:') or c.startswith('meth:')): return 'bb_rk_dispatch to rtx_rk_io_' + re.sub(r'[^a-z0-9]', '_', c.split(':', 1)[1].lower()) + ' (ASM leaf over the syscall; the syscall is NOT-A-BOX: a kernel entry)'
    if fam == 'F08' and c.startswith(('meth:', 'call:')): return 'bb_rk_dispatch to rtx_rk_str_' + re.sub(r'[^a-z0-9]', '_', c.split(':', 1)[1].lower()) + ' (ASM leaf); the method body is SETTING Raku'
    if fam == 'F09' and c.startswith(('meth:', 'call:')): return 'bb_rk_num to rtx_rk_num_' + re.sub(r'[^a-z0-9]', '_', c.split(':', 1)[1].lower()) + ' (ASM leaf over libm or the bigint/rat leaves); the method body is SETTING Raku'
    return FAM_BOX[fam]

SYM = {'+':'plus','-':'minus','*':'star','/':'slash','%':'percent','~':'tilde','=':'eq','<':'lt','>':'gt','!':'bang','?':'qm','|':'pipe','&':'amp','^':'caret',':':'colon','.':'dot',',':'comma',
       '(':'lp',')':'rp','[':'lb',']':'rb','{':'lc','}':'rc','«':'laq','»':'raq','∈':'elem','∉':'notelem','∪':'union','∩':'isect','∖':'setdiff','⊂':'subset','⊃':'superset','⊆':'subseteq','⊇':'superseteq',
       '≤':'le','≥':'ge','≠':'ne','×':'times','÷':'div','…':'ellip','−':'minus','$':'dollar','@':'at','#':'hash','\\':'bslash','\'':'sq','"':'dq','`':'bt',';':'semi','_':'us'}
def slug(c):
    fam, name = c.split(':', 1) if ':' in c else ('x', c)
    out = []
    for ch in name:
        if ch.isalnum(): out.append(ch)
        elif ch in SYM: out.append('_' + SYM[ch] + '_')
        elif ch in '- ': out.append('_')
        else: out.append('_u%04x_' % ord(ch))
    s = re.sub(r'_+', '_', ''.join(out)).strip('_')
    return (fam + '_' + s).lower()[:48]

def load_core():
    if not os.path.exists(CORE):
        txt = subprocess.run(['/usr/bin/raku', '-e', 'say CORE::.keys.sort.join("\\n")'], capture_output=True, text=True, timeout=120).stdout
        with open(CORE, 'w') as f:
            f.write('# CORE-NAMES.tsv -- the keys of Raku CORE:: as /usr/bin/raku prints them (written once by util_raku_ladder_design.py; the classing of call:, type: and &-names reads it)\n' + txt)
    return set(l.strip() for l in open(CORE) if l.strip() and not l.startswith('#'))

def classify(c, core, meths):
    if ':' not in c: return None
    fam, name = c.split(':', 1)
    if not name.strip(): return None
    if c in BUILT: return None
    if fam == 'lit' or fam == 'quote': return 'F01'
    if fam == 'var': return 'F02'
    if fam == 'twigil': return {'*': 'F18', '?': 'F17', '=': 'F17', '.': 'F10', '!': 'F10', '^': 'F06', '<': 'F13', ':': 'F06', '~': 'F17'}.get(name, 'F02')
    if fam == 'regex': return 'F13'
    if fam == 'meta': return 'F03'
    if fam == 'test': return 'F11' if name in TEST_EXC else 'F11'
    if fam == 'kw': return KW_FAM.get(name, 'F04')
    if fam == 'op':
        if name in OP_FAM: return OP_FAM[name]
        if name.startswith('(') or name in SET_OPS: return 'F19'
        if name.startswith('>>') or name.startswith('<<') or name.startswith('«') or name.startswith('»') or name.startswith('[') or name.startswith('R') or name.startswith('X') or name.startswith('Z'): return 'F03'
        return 'F03'
    if fam == 'word':
        if name in CORE_WORDS_FAM: return CORE_WORDS_FAM[name]
        return None
    if fam == 'type':
        if name.startswith(EXC_TYPES_PREFIX): return 'F11'
        if name in CONC_TYPES: return 'F20'
        if name in SET_TYPES: return 'F19'
        if name in REGEX_TYPES: return 'F13'
        if name in IO_TYPES or name.startswith('IO::'): return 'F16'
        if name in NUM_TYPES: return 'F09'
        if name in STR_TYPES: return 'F08'
        if name in LIST_TYPES: return 'F07'
        if name in MOP_TYPES: return 'F10'
        if name in INTRO_TYPES: return 'F18'
        if name in ('Junction',): return 'F12'
        if name in ('Bool', 'Whatever', 'WhateverCode', 'HyperWhatever', 'Nil'): return 'F01'
        if name in core or name in ('Test', 'Test::Util'): return 'F14'
        return None
    if fam == 'meth':
        if name in ('WHAT', 'WHO', 'HOW', 'WHICH', 'WHERE', 'VAR', 'DEFINITE') or name.startswith('^'): return 'F18' if name in ('WHERE', 'VAR', 'DEFINITE') else 'F10'
        if name in IO_METHS: return 'F16'
        if name in SET_TYPES or name in ('Set', 'Bag', 'Mix', 'SetHash', 'BagHash', 'MixHash', 'total'): return 'F19'
        if name in ('match', 'subst', 'parse', 'subparse', 'parsefile', 'made', 'make', 'caps', 'chunks', 'pos', 'from', 'to', 'orig', 'prematch', 'postmatch', 'ast'): return 'F13'
        if name in EXC_METHS and name not in ('gist', 'Str', 'defined', 'so', 'not'): return 'F11'
        if name in MOP_METHS: return 'F10'
        if name in NUM_METHS: return 'F09'
        if name in STR_METHS: return 'F08'
        if name in LIST_METHS: return 'F07'
        if name in ('then', 'result', 'keep', 'break', 'tap', 'act', 'Supply', 'Channel', 'send', 'receive', 'close', 'poll', 'list', 'emit'): return 'F20' if name in ('then', 'result', 'keep', 'break', 'tap', 'act', 'Supply', 'Channel', 'send', 'receive', 'poll', 'emit') else 'F07'
        if name in PAIR_METHS: return 'F07'
        if name in DATE_METHS: return 'F14'
        if name in ROUTINE_METHS: return 'F05'
        if name in ('EVAL', 'EVALFILE'): return 'F17'
        return None
    if fam == 'call':
        if name in ('lib', 'is_run', 'test-assertion', 'originally', 'the', 'begin', 'end'): return None if name != 'lib' else 'F17'
        if name in IO_CALLS: return 'F16'
        if name in NUM_CALLS: return 'F09'
        if name in STR_CALLS: return 'F08'
        if name in LIST_CALLS: return 'F07'
        if name in ('set', 'bag', 'mix'): return 'F19'
        if name in ('any', 'all', 'one', 'none', 'so', 'not'): return 'F12'
        if name in ('die', 'fail', 'warn', 'throw'): return 'F11'
        if name in ('callframe', 'callsame', 'callwith', 'nextsame', 'nextwith', 'samewith', 'nextcallee', 'lastcall'): return 'F05'
        if name in ('await', 'start', 'emit', 'done', 'signal', 'cas'): return 'F20'
        if name in ('EVAL', 'EVALFILE', 'require'): return 'F17'
        if name in ('make', 'made'): return 'F13'
        if ('&' + name) in core: return 'F05'
        return None
    return None

def placement_data():
    """The rule's data per red program of the snapshot: red {program: outcome}, prog_cons {program: its feature constructs, the
    refusal override among them}, override {program: the construct its emitter refusal names}, fam_of {construct: family}, norm.
    util_raku_ladder_status.py --replace reads the same data, so the generator and the instrument place by one rule."""
    core = load_core()
    meths = set(re.findall(r'"([^"]+)"', open(METH).read()))
    red = {}
    for l in open(SN):
        if l.startswith('PROGRAM'):
            f = l.rstrip('\n').split('\t'); red[f[1]] = f[2]
    last = {}
    for line in open(RESULTS, encoding='utf-8', errors='replace'):
        f = line.rstrip('\n').split('\t')
        if len(f) >= 12 and f[5] == 'roast' and f[8] == 'm3': last[f[7]] = f[11]
    norm = lambda p: re.sub(r'^6\.[cde]/', '', re.sub(r'\.t$', '', p))
    bytest = collections.defaultdict(list)
    for l in open(TESTS, encoding='utf-8', errors='replace'):
        if l.startswith('#') or l.startswith('rung\t'): continue
        f = l.rstrip('\n').split('\t')
        if len(f) >= 8: bytest[norm(f[1])].append(f)
    SYN = {'decl:list': 'F02', 'decl:sigilless': 'F02', 'term:typeobject': 'F14', 'stmt:excised': 'F06', 'op:ternary_rhs': 'F03'}
    files_of = collections.defaultdict(set); fam_of = {}
    prog_cons = {}; override = {}
    for p, o in red.items():
        cons = set()
        for r in bytest.get(norm(p), []):
            for c in r[6].split():
                if c.startswith('type:X::'): c = 'type:' + '::'.join(c[5:].split('::')[:2])
                fam = classify(c, core, meths)
                if fam: cons.add(c); fam_of[c] = fam
        note = last.get(p, '')
        m = re.search(r'does not yet cover this program: (.*)', note)
        if m:
            t = m.group(1)
            mv = re.match(r"variable '([^']*)'", t)
            ov = None
            if mv:
                v = mv.group(1)
                if v == '=pod' or v.startswith('='): ov = 'word:pod'
                elif v.startswith('?') or v.startswith('$?'): ov = 'twigil:?'
                elif v in ('self',): ov = 'kw:self'
                elif v[0] in '$@%&': ov = 'decl:list'
                elif v in core or v[0].isupper(): ov = 'term:typeobject'
                else: ov = 'decl:sigilless'
            elif 'tern' in t: ov = 'op:ternary_rhs'
            elif 'IR_EXCISED' in t: ov = 'stmt:excised'
            if ov:
                override[p] = ov
                if ov in SYN: fam_of[ov] = SYN[ov]
                elif ov in BUILT: fam_of[ov] = {'kw:self': 'F10'}.get(ov, 'F02'); 
                else: fam_of[ov] = classify(ov, core, meths) or SYN.get(ov, 'F02')
                cons.add(ov)
        prog_cons[p] = cons
        for c in cons: files_of[c].add(p)
    return red, prog_cons, override, fam_of, files_of, norm

def main():
    red, prog_cons, override, fam_of, files_of, norm = placement_data()
    # rungs: families in order, constructs by red-file count desc then name
    rungs = []
    for fam, _, _ in FAMILIES:
        cs = [c for c in files_of if fam_of.get(c) == fam]
        cs.sort(key=lambda c: (-len(files_of[c]), c))
        rungs.extend(cs)
    rung_no = {c: 21 + i for i, c in enumerate(rungs)}
    first_of_fam = {}
    for c in rungs: first_of_fam.setdefault(fam_of[c], rung_no[c])
    CH = {'S02-types': 'F14', 'S02-literals': 'F01', 'S02-names': 'F02', 'S02-names-vars': 'F02', 'S02-lexical-conventions': 'F17', 'S02-lists': 'F07', 'S02-magicals': 'F18', 'S02-one-pass-parsing': 'F17',
          'S03-operators': 'F03', 'S03-smartmatch': 'F12', 'S03-junctions': 'F12', 'S03-metaops': 'F03', 'S03-sequence': 'F07', 'S03-binding': 'F02', 'S03-feeds': 'F07', 'S03-buf': 'F08',
          'S04-statements': 'F04', 'S04-phasers': 'F15', 'S04-exceptions': 'F11', 'S04-blocks-and-statements': 'F06', 'S04-declarations': 'F02', 'S04-statement-modifiers': 'F04', 'S04-exception-handlers': 'F11', 'S04-exception-handlers': 'F11',
          'S05-grammar': 'F13', 'S05-match': 'F13', 'S05-capture': 'F13', 'S05-mass': 'F13', 'S05-metachars': 'F13', 'S05-metasyntax': 'F13', 'S05-modifier': 'F13', 'S05-nonstrings': 'F13', 'S05-substitution': 'F13', 'S05-syntactic-categories': 'F13', 'S05-transliteration': 'F13', 'S05-interpolation': 'F13',
          'S06-signature': 'F05', 'S06-multi': 'F05', 'S06-currying': 'F06', 'S06-advanced': 'F05', 'S06-other': 'F05', 'S06-traits': 'F05', 'S06-operator-overloading': 'F05', 'S06-macros': 'F17', 'S06-routine-modifiers': 'F05', 'S06-parameters': 'F05',
          'S07-hyperrace': 'F20', 'S07-iterators': 'F07', 'S07-slip': 'F07', 'S09-autovivification': 'F07', 'S09-hashes': 'F07', 'S09-multidim': 'F07', 'S09-subscript': 'F07', 'S09-typed-arrays': 'F14',
          'S10-packages': 'F17', 'S11-compunit': 'F17', 'S11-modules': 'F17', 'S11-repository': 'F17', 'S12-attributes': 'F10', 'S12-class': 'F10', 'S12-coercive-conversions': 'F14', 'S12-construction': 'F10', 'S12-enums': 'F14', 'S12-introspection': 'F18', 'S12-meta': 'F10', 'S12-methods': 'F10', 'S12-subset': 'F14', 'S12-traits': 'F10', 'S13-overloading': 'F05', 'S13-syntax': 'F05', 'S13-type-casting': 'F14', 'S14-roles': 'F10', 'S14-traits': 'F10',
          'S15-literals': 'F08', 'S15-nfg': 'F08', 'S15-normalization': 'F08', 'S15-string-types': 'F08', 'S15-unicode-information': 'F08', 'S16-filehandles': 'F16', 'S16-io': 'F16', 'S16-unfiled': 'F16', 'S17-channel': 'F20', 'S17-lowlevel': 'F20', 'S17-procasync': 'F20', 'S17-promise': 'F20', 'S17-scheduler': 'F20', 'S17-supply': 'F20', 'S17-supply-coercion': 'F20', 'S17-supply-recent': 'F20', 'S19-command-line': 'F16', 'S19-command-line-options': 'F16',
          'S22-package-format': 'F17', 'S24-testing': 'F11', 'S26-documentation': 'F17', 'S28-named-variables': 'F18', 'S29-any': 'F07', 'S29-context': 'F18', 'S29-conversions': 'F14', 'S29-os': 'F16',
          'S32-array': 'F07', 'S32-basics': 'F02', 'S32-calling': 'F18', 'S32-container': 'F07', 'S32-context': 'F18', 'S32-encoding': 'F08', 'S32-exceptions': 'F11', 'S32-hash': 'F07', 'S32-io': 'F16', 'S32-list': 'F07', 'S32-num': 'F09', 'S32-scalar': 'F02', 'S32-setbag': 'F19', 'S32-str': 'F08', 'S32-temporal': 'F14', 'S32-trig': 'F09', 'integration': 'F10', 'APPENDICES': 'F17', 'MISC': 'F17', 'rosettacode': 'F10'}
    placed = []; basis_ct = collections.Counter(); first_ct = collections.Counter(); unblock_ct = collections.Counter()
    for p, o in sorted(red.items()):
        cons = prog_cons[p]
        if cons:
            nums = sorted(rung_no[c] for c in cons)
            if p in override and override[p] in rung_no:
                first = rung_no[override[p]]; basis = 'refusal:' + override[p]
            else:
                first = nums[0]; basis = 'tests'
            last_r = max(nums[-1], first); cfirst = [c for c in cons if rung_no[c] == first][0]
        else:
            ch = norm(p).split('/')[0]
            fam = CH.get(ch, CH.get(norm(p).split('/')[0].split('-')[0], 'F17'))
            first = first_of_fam.get(fam, 21); last_r = first; basis = 'chapter:' + ch; cfirst = rungs[first - 21]
        placed.append((p, first, last_r, o, basis, cfirst)); basis_ct[basis.split(':')[0]] += 1; first_ct[first] += 1; unblock_ct[last_r] += 1
    fam_rows = collections.Counter(fam_of[c] for c in rungs)
    # outputs
    if not DRY:
        with open(MAP, 'w') as f:
            f.write('# ROAST-RUNG-MAP.tsv -- every Roast program of the CEO-2044 snapshot (not PASS at the 11:41 reading) on the rung that FIRST blocks it (column 2) and the rung that UNBLOCKS it (column 3: the highest rung among the features its tests exercise), with its outcome, the basis of the placement (tests: TESTS.tsv constructs; refusal:<construct>: the emitter refusal named it; chapter:<dir>: no feature row, placed at the chapter family first rung) and the first-blocking construct; written by harness/scripts/util_raku_ladder_design.py (ARCH-RAKU-TO-100 section 3). A program moves up the map as rungs go green; a program still red with every rung green gains a FORM on its unblock rung.\n')
            f.write('# program\tfirst_rung\tunblock_rung\toutcome\tbasis\tconstruct\n')
            for p, a, b, o, bs, c in placed: f.write(f'{p}\trung{a:03d}\trung{b:03d}\t{o}\t{bs}\t{c}\n')
        lad = open(LADDER).read().rstrip('\n').split('\n')
        lad = [l for l in lad if not re.match(r'^rung(0[2-9][0-9]|[1-9][0-9][0-9])\t', l)]
        for c in rungs:
            n = rung_no[c]; fam = fam_of[c]; s = slug(c)
            status = 'HELD' if fam == 'F20' else 'DECLARED'
            lad.append(f'rung{n:03d}\t{s}\troast construct {c} ({len(files_of[c])} red programs exercise it; family {fam} {dict((x[0], x[1]) for x in FAMILIES)[fam]}; ARCH-RAKU-TO-100 section 3)\t{s}\t\tladder__rung{n:03d}_{s}\t{status}\tthe cto 2026-10-30 (CEO-2044..2046): declared by util_raku_ladder_design.py; first block of {first_ct[n]} programs, unblock rung of {unblock_ct[n]}; the forms are cut from the failing Roast tests by the builder, one program at a time, each at most 20 lines, its ref from rakudo 2026.05')
        open(LADDER, 'w').write('\n'.join(lad) + '\n')
    FB = {f[0]: f[2] for f in FAMILIES}
    print(f'RUNGS {len(rungs)} families ' + ' '.join(f'{k}={v}' for k, v in sorted(fam_rows.items())))
    print(f'PLACED {len(placed)} basis ' + ' '.join(f'{k}={v}' for k, v in basis_ct.items()))
    nab = sum(1 for c in rungs if box_of(c, fam_of[c]).startswith('NOT-A-BOX:'))
    famfirst = collections.Counter(fam_of[rungs[a - 21]] for _, a, _, _, _, _ in placed)
    print(f'NOT_A_BOX {nab} of {len(rungs)} rungs; first-block programs per family ' + ' '.join(f'{k}={v}' for k, v in sorted(famfirst.items())))
    top = sorted(first_ct.items(), key=lambda x: -x[1])[:24]
    print('TOP_FIRST ' + ' '.join(f'rung{n:03d}:{rungs[n-21]}={v}' for n, v in top))
    print('TABLE')
    cur = None
    for c in rungs:
        fam = fam_of[c]
        if fam != cur:
            cur = fam; ft = dict((x[0], x[1]) for x in FAMILIES)[fam]
            print(f'| **{fam} {ft}** | | | | | | {FB[fam]} |')
        n = rung_no[c]
        print(f'| rung{n:03d} | `{c}` | {fam} | {len(files_of[c])} | {first_ct[n]} | {unblock_ct[n]} | {box_of(c, fam)} |')
if __name__ == '__main__': main()
