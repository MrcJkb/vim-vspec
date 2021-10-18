" vspec - Testing framework for Vim script
" Version: 1.9.2
" Copyright (C) 2009-2021 Kana Natsuno <https://whileimautomaton.net/>
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}

" NB: Script-local variables created by the following :import syntax behave
" differently from normal ones.  For example:
" {{{
"     import * as Vim9 from '../import/vspec.vim'
"
"     let s:Normal = {}
"     let s:Normal.Return42 = s:Vim9.Return42
"
"     echo s:Normal
"     " ==> {'Return42': function('<80><fd>R2_Return42')}
"     echo s:Vim9
"     " ==> E1029: Expected '.' but got
"
"     echo s:Normal.Return42
"     " ==> <80><fd>R2_Return42
"     echo s:Vim9.Return42
"     " ==> <80><fd>R2_Return42
"
"     echo s:Normal.Return42()
"     " ==> 42
"     echo s:Vim9.Return42()
"     " ==> 42
"
"     call s:Normal.Return42()
"     " ==> No error.
"     call s:Vim9.Return42()
"     " ==> E121: Undefined variable: s:Vim9
"     " This variable seems to be available only in a context where arbitrary
"     " expressions are available.  (:call basically takes a function 'name'.)
"
"     eval s:Normal.Return42()
"     " ==> No error.
"     eval s:Vim9.Return42()
"     " ==> No error.
" }}}

import {
\   BreakLineForcibly,
\   Call,
\   GetHintedScope,
\   GetHintedSid,
\   GetInternalCallStackForExpect,
\   ParseString,
\   Ref,
\   ResetContext,
\   SaveContext,
\   SimplifyCallStack,
\   ThrowInternalException
\ } from '../import/vspec.vim'

" Constants  "{{{1
" Fundamentals  "{{{2

let s:FALSE = 0
let s:TRUE = !0








" Variables  "{{{1
let s:all_suites = []  "{{{2
" :: [Suite]




let s:custom_matchers = {}  "{{{2
" :: MatcherNameString -> Matcher




" s:expr_hinted_scope  "{{{2
let s:expr_hinted_scope =
\ 's:ThrowInternalException("InvalidOperation", {"message": "Scope hint is not given"})'
" An expression which is evaluated to a script-local scope for Ref()/Set().




" s:expr_hinted_sid  "{{{2
let s:expr_hinted_sid =
\ 's:ThrowInternalException("InvalidOperation", {"message": "SID hint is not given"})'
" An expression which is evaluated to a <SID> for Call().




let s:saved_scope = {}  "{{{2
" A snapshot of a script-local variables for :SaveContext/:ResetContext.




let s:suite = {}  "{{{2
" The prototype for suites.








" Interface  "{{{1
" :Debug  "{{{2
command! -complete=expression -nargs=+ Debug
\   call s:BreakLineForcibly()
\ | echo '#' <args>




" :Expect  "{{{2
command! -complete=expression -nargs=+ Expect
\   if <q-args> =~# '^expr\s*{'
\ |   let s:_ = {}
\ |   let [s:_.ae, s:_.ne, s:_.me, s:_.ee] =
\      s:parse_should_arguments(<q-args>, 'eval')
\ |   let s:_.nv = eval(s:_.ne)
\ |   let s:_.mv = eval(s:_.me)
\ |   let s:_.ev = eval(s:_.ee)
\ |   let s:_.av = 0
\ |   let s:_.ax = 0
\ |   let s:_.at = 0
\ |   try
\ |     let s:_.av = eval(substitute(s:_.ae, '^expr\s*{\s*\(.*\S\)\s*}$', '\1', ''))
\ |   catch
\ |     let s:_.ax = v:exception
\ |     let s:_.at = v:throwpoint
\ |   endtry
\ |   call s:cmd_Expect(
\       s:parse_should_arguments(<q-args>, 'raw'),
\       [{'value': s:_.av, 'exception': s:_.ax, 'throwpoint': s:_.at},
\        s:_.nv, s:_.mv, s:_.ev]
\     )
\ | else
\ |   call s:cmd_Expect(
\       s:parse_should_arguments(<q-args>, 'raw'),
\       map(s:parse_should_arguments(<q-args>, 'eval'), 'eval(v:val)')
\     )
\ | endif




" :ResetContext  "{{{2
command! -bar -nargs=0 ResetContext
\ call s:ResetContext()




" :SaveContext  "{{{2
command! -bar -nargs=0 SaveContext
\ call s:SaveContext()




" :SKIP  "{{{2
command! -nargs=+ SKIP
\ call s:ThrowInternalException('ExpectationFailure',
\              {'type': 'SKIP', 'message': s:ParseString(<q-args>)})




" :TODO  "{{{2
command! -bar -nargs=0 TODO
\ call s:ThrowInternalException('ExpectationFailure', {'type': 'TODO'})




function! Call(function_name, args)  "{{{2
  return s:Call(a:function_name, a:args)
endfunction




function! Ref(...)  "{{{2
  return call('vspec#ref', a:000)
endfunction




function! Set(...)  "{{{2
  return call('vspec#set', a:000)
endfunction




function! vspec#call(function_name, args)  "{{{2
  " Deprecated.  Kept for backward compatibility.
  return s:Call(a:function_name, a:args)
endfunction




function! vspec#customize_matcher(matcher_name, maybe_matcher)  "{{{2
  if type(a:maybe_matcher) == type({})
    let matcher = a:maybe_matcher
  else
    let matcher = {'match': a:maybe_matcher}
  endif
  let s:custom_matchers[a:matcher_name] = matcher
endfunction




function! vspec#debug(...)  "{{{2
  " Deprecated.  Kept for backward compatibility.
  call s:BreakLineForcibly()
  echo '#' join(a:000, ' ')
endfunction




function! vspec#hint(info)  "{{{2
  if has_key(a:info, 'scope')
    let s:expr_hinted_scope = a:info.scope
    call s:SaveContext()
  endif

  if has_key(a:info, 'sid')
    let s:expr_hinted_sid = a:info.sid
  endif
endfunction




function! vspec#pretty_string(value)  "{{{2
  return substitute(
  \   string(a:value),
  \   '''\(\%([^'']\|''''\)*\)''',
  \   '\=s:reescape_string_content(submatch(1))',
  \   'g'
  \ )
endfunction

function! s:reescape_string_content(s)
  if !exists('s:REESCAPE_TABLE')
    let s:REESCAPE_TABLE = {}
    for i in range(0x01, 0xFF)
      let c = nr2char(i)
      let s:REESCAPE_TABLE[c] = c =~# '\p' ? c : printf('\x%02X', i)
    endfor
    call extend(s:REESCAPE_TABLE, {
    \   "\"": '\"',
    \   "\\": '\\',
    \   "\b": '\b',
    \   "\e": '\e',
    \   "\f": '\f',
    \   "\n": '\n',
    \   "\r": '\r',
    \   "\t": '\t',
    \ })
  endif
  let s = substitute(a:s, "''", "'", 'g')
  let cs = map(split(s, '\ze.'), 'get(s:REESCAPE_TABLE, v:val, v:val)')
  return '"' . join(cs, '') . '"'
endfunction




function! vspec#ref(variable_name)  "{{{2
  return s:Ref(a:variable_name)
endfunction




function! vspec#set(variable_name, value)  "{{{2
  if a:variable_name =~# '^s:'
    let _ = s:GetHintedScope()
    let _[a:variable_name[2:]] = a:value
  else
    call s:ThrowInternalException(
    \   'InvalidOperation',
    \   {'message': 'Invalid variable_name - ' . string(a:variable_name)}
    \ )
  endif
endfunction




function! vspec#test(specfile_path)  "{{{2
  let compiled_specfile_path = tempname()
  call s:compile_specfile(a:specfile_path, compiled_specfile_path)

  try
    execute 'source' compiled_specfile_path
    call s:run_suites(s:all_suites)
  catch
    echo '#' repeat('-', 77)
    echo '#' s:SimplifyCallStack(v:throwpoint, expand('<sfile>'), 'unknown')
    for exception_line in split(v:exception, '\n')
      echo '#' exception_line
    endfor
    echo 'Bail out!  Unexpected error happened while processing a test script.'
  finally
    call s:BreakLineForcibly()
  endtry

  call delete(compiled_specfile_path)
endfunction

function! s:run_suites(all_suites)
  let total_count_of_examples = 0
  for suite in a:all_suites
    for example_index in range(len(suite.example_list))
      let total_count_of_examples += 1
      let example = suite.example_list[example_index]
      call suite.run_before_blocks()

      try
        call suite.example_dict[
        \   suite.generate_example_function_name(example_index)
        \ ]()
        call s:BreakLineForcibly()  " anti-:redraw
        echo printf(
        \   '%s %d - %s %s',
        \   'ok',
        \   total_count_of_examples,
        \   suite.pretty_subject,
        \   example
        \ )
      catch /^vspec:/
        call s:BreakLineForcibly()  " anti-:redraw
        let xs = matchlist(v:exception, '^vspec:\(\a\+\):\(.*\)$')
        let type = xs[1]
        let i = eval(xs[2])
        if type ==# 'ExpectationFailure'
          let subtype = i.type
          if subtype ==# 'MismatchedValues'
            echo printf(
            \   '%s %d - %s %s',
            \   'not ok',
            \   total_count_of_examples,
            \   suite.pretty_subject,
            \   example
            \ )
            echo '# Expected' join(filter([
            \   i.expr_actual,
            \   i.expr_not,
            \   i.expr_matcher,
            \   i.expr_expected,
            \ ], 'v:val != ""'))
            \ 'at line' s:SimplifyCallStack(v:throwpoint, '', 'expect')
            for line in s:generate_failure_message(i)
              echo '#     ' . line
            endfor
          elseif subtype ==# 'TODO'
            echo printf(
            \   '%s %d - # TODO %s %s',
            \   'not ok',
            \   total_count_of_examples,
            \   suite.pretty_subject,
            \   example
            \ )
          elseif subtype ==# 'SKIP'
            echo printf(
            \   '%s %d - # SKIP %s %s - %s',
            \   'ok',
            \   total_count_of_examples,
            \   suite.pretty_subject,
            \   example,
            \   i.message
            \ )
          else
            echo printf(
            \   '%s %d - %s %s',
            \   'not ok',
            \   total_count_of_examples,
            \   suite.pretty_subject,
            \   example
            \ )
            echo printf('# %s: %s', type, i.message)
          endif
        else
          echo printf(
          \   '%s %d - %s %s',
          \   'not ok',
          \   total_count_of_examples,
          \   suite.pretty_subject,
          \   example
          \ )
          echo printf('# %s: %s', type, i.message)
        endif
      catch
        call s:BreakLineForcibly()  " anti-:redraw
        echo printf(
        \   '%s %d - %s %s',
        \   'not ok',
        \   total_count_of_examples,
        \   suite.pretty_subject,
        \   example
        \ )
        echo '#' s:SimplifyCallStack(v:throwpoint, expand('<sfile>'), 'it')
        for exception_line in split(v:exception, '\n')
          echo '#' exception_line
        endfor
      endtry
      call suite.run_after_blocks()
    endfor
  endfor
  echo printf('1..%d', total_count_of_examples)
endfunction




" Predefined custom matchers - to_be_false  "{{{2

let s:to_be_false = {}

function! s:to_be_false.match(value)
  return type(a:value) == type(0) ? !(a:value) : s:FALSE
endfunction

function! s:to_be_false.failure_message_for_should(value)
  return 'Actual value: ' . vspec#pretty_string(a:value)
endfunction

let s:to_be_false.failure_message_for_should_not =
\ s:to_be_false.failure_message_for_should

call vspec#customize_matcher('to_be_false', s:to_be_false)
call vspec#customize_matcher('toBeFalse', s:to_be_false)




" Predefined custom matchers - to_be_true  "{{{2

let s:to_be_true = {}

function! s:to_be_true.match(value)
  return type(a:value) == type(0) ? !!(a:value) : s:FALSE
endfunction

function! s:to_be_true.failure_message_for_should(value)
  return 'Actual value: ' . vspec#pretty_string(a:value)
endfunction

let s:to_be_true.failure_message_for_should_not =
\ s:to_be_true.failure_message_for_should

call vspec#customize_matcher('to_be_true', s:to_be_true)
call vspec#customize_matcher('toBeTrue', s:to_be_true)








" Predefined custom matchers - to_throw  "{{{2

let s:to_throw = {}

function! s:to_throw.match(result, ...)
  return a:result.exception isnot 0 && (a:0 == 0 || a:result.exception =~# a:1)
endfunction

function! s:to_throw.failure_message_for_should(result, ...)
  return printf(
  \   'But %s was thrown',
  \   a:result.exception is 0 ? 'nothing' : string(a:result.exception)
  \ )
endfunction

let s:to_throw.failure_message_for_should_not =
\ s:to_throw.failure_message_for_should

call vspec#customize_matcher('to_throw', s:to_throw)








" Suites  "{{{1
function! s:suite.add_example(example_description)  "{{{2
  call add(self.example_list, a:example_description)
endfunction




function! s:suite.after_block()  "{{{2
  " No-op to avoid null checks.
endfunction




function! s:suite.before_block()  "{{{2
  " No-op to avoid null checks.
endfunction




function! s:suite.generate_example_function_name(example_index)  "{{{2
  return '_' . a:example_index
endfunction




function! s:suite.has_parent()  "{{{2
  return !empty(self.parent)
endfunction




function! s:suite.run_after_blocks()  "{{{2
  call self.after_block()
  if self.has_parent()
    call self.parent.run_after_blocks()
  endif
endfunction




function! s:suite.run_before_blocks()  "{{{2
  if self.has_parent()
    call self.parent.run_before_blocks()
  endif
  call self.before_block()
endfunction




function! vspec#add_suite(suite)  "{{{2
  call add(s:all_suites, a:suite)
endfunction




function! vspec#new_suite(subject, parent_suite)  "{{{2
  let s = copy(s:suite)

  let s.subject = a:subject  " :: SubjectString
  let s.parent = a:parent_suite  " :: Suite
  let s.pretty_subject = s.has_parent()
  \                      ? s.parent.pretty_subject . ' ' . s.subject
  \                      : s.subject
  let s.example_list = []  " :: [DescriptionString]
  let s.example_dict = {}  " :: ExampleIndexAsIdentifier -> ExampleFuncref

  return s
endfunction








" Compiler  "{{{1
function! s:compile_specfile(specfile_path, result_path)  "{{{2
  let slines = readfile(a:specfile_path)
  let rlines = s:translate_script(slines)
  call writefile(rlines, a:result_path)
endfunction




function! s:translate_script(slines)  "{{{2
  let rlines = []
  let stack = []

  call add(rlines, 'let suite_stack = [{}]')

  for sline in a:slines
    let tokens = matchlist(sline, '^\s*\%(describe\|context\)\s*\(\(["'']\).*\2\)\s*$')
    if !empty(tokens)
      call insert(stack, 'describe', 0)
      call extend(rlines, [
      \   printf('let suite = vspec#new_suite(%s, suite_stack[-1])', tokens[1]),
      \   'call vspec#add_suite(suite)',
      \   'call add(suite_stack, suite)',
      \ ])
      continue
    endif

    let tokens = matchlist(sline, '^\s*it\s*\(\(["'']\).*\2\)\s*$')
    if !empty(tokens)
      call insert(stack, 'it', 0)
      call extend(rlines, [
      \   printf('call suite.add_example(%s)', tokens[1]),
      \   'function! suite.example_dict[suite.generate_example_function_name(len(suite.example_list) - 1)]()',
      \ ])
      continue
    endif

    let tokens = matchlist(sline, '^\s*before\s*$')
    if !empty(tokens)
      call insert(stack, 'before', 0)
      call extend(rlines, [
      \   'function! suite.before_block()',
      \ ])
      continue
    endif

    let tokens = matchlist(sline, '^\s*after\s*$')
    if !empty(tokens)
      call insert(stack, 'after', 0)
      call extend(rlines, [
      \   'function! suite.after_block()',
      \ ])
      continue
    endif

    let tokens = matchlist(sline, '^\s*end\s*$')
    if !empty(tokens)
      let type = remove(stack, 0)
      if type ==# 'describe'
        call extend(rlines, [
        \   'call remove(suite_stack, -1)',
        \   'let suite = suite_stack[-1]',
        \ ])
      elseif type ==# 'it'
        call extend(rlines, [
        \   'endfunction',
        \ ])
      elseif type ==# 'before'
        call extend(rlines, [
        \   'endfunction',
        \ ])
      elseif type ==# 'after'
        call extend(rlines, [
        \   'endfunction',
        \ ])
      else
        " Nothing to do.
      endif
      continue
    endif

    call add(rlines, sline)
  endfor

  return rlines
endfunction








" :Expect magic  "{{{1
function! s:cmd_Expect(exprs, vals)  "{{{2
  let d = {}
  let [d.expr_actual, d.expr_not, d.expr_matcher, d.expr_expected] = a:exprs
  let [d.value_actual, d.value_not, d.value_matcher, d.value_expected] = a:vals

  let truth = d.value_not ==# ''
  if truth != s:are_matched(d.value_actual, d.value_matcher, d.value_expected)
    let d.type = 'MismatchedValues'
    call s:ThrowInternalException('ExpectationFailure', d)
  endif
endfunction




function! s:parse_should_arguments(s, mode)  "{{{2
  let tokens = s:split_at_matcher(a:s)
  let [_actual, _not, _matcher, _expected] = tokens
  let [actual, not, matcher, expected] = tokens

  if a:mode ==# 'eval'
    if s:is_matcher(_matcher)
      let matcher = string(_matcher)
    endif
    if s:is_custom_matcher(_matcher)
      let expected = '[' . _expected . ']'
    endif
    let not = string(_not)
  endif

  return [actual, not, matcher, expected]
endfunction








" Matchers  "{{{1
" Constants  "{{{2

let s:VALID_MATCHERS_EQUALITY = [
\   '!=',
\   '==',
\   'is',
\   'isnot',
\
\   '!=?',
\   '==?',
\   'is?',
\   'isnot?',
\
\   '!=#',
\   '==#',
\   'is#',
\   'isnot#',
\ ]

let s:VALID_MATCHERS_REGEXP = [
\   '!~',
\   '=~',
\
\   '!~?',
\   '=~?',
\
\   '!~#',
\   '=~#',
\ ]

let s:VALID_MATCHERS_ORDERING = [
\   '<',
\   '<=',
\   '>',
\   '>=',
\
\   '<?',
\   '<=?',
\   '>?',
\   '>=?',
\
\   '<#',
\   '<=#',
\   '>#',
\   '>=#',
\ ]

let s:VALID_MATCHERS = (s:VALID_MATCHERS_EQUALITY
\                       + s:VALID_MATCHERS_ORDERING
\                       + s:VALID_MATCHERS_REGEXP)




function! s:are_matched(value_actual, expr_matcher, value_expected)  "{{{2
  if s:is_custom_matcher(a:expr_matcher)
    let custom_matcher_name = a:expr_matcher
    let matcher = get(s:custom_matchers, custom_matcher_name, 0)
    if matcher is 0
      call s:ThrowInternalException(
      \   'InvalidOperation',
      \   {'message': 'Unknown custom matcher - '
      \               . string(custom_matcher_name)}
      \ )
    endif
    let Match = get(matcher, 'match', 0)
    if Match is 0
      call s:ThrowInternalException(
      \   'InvalidOperation',
      \   {'message': 'Custom matcher does not have match function - '
      \               . string(custom_matcher_name)}
      \ )
    endif
    return !!call(
    \   Match,
    \   [a:value_actual] + a:value_expected,
    \   matcher
    \ )
  elseif s:is_equality_matcher(a:expr_matcher)
    let type_equality = type(a:value_actual) == type(a:value_expected)
    if s:is_negative_matcher(a:expr_matcher) && !type_equality
      return s:TRUE
    else
      return type_equality && eval('a:value_actual ' . a:expr_matcher . ' a:value_expected')
    endif
  elseif s:is_ordering_matcher(a:expr_matcher)
    if (type(a:value_actual) != type(a:value_expected)
    \   || !s:is_orderable_type(a:value_actual)
    \   || !s:is_orderable_type(a:value_expected))
      return s:FALSE
    endif
    return eval('a:value_actual ' . a:expr_matcher . ' a:value_expected')
  elseif s:is_regexp_matcher(a:expr_matcher)
    if type(a:value_actual) != type('') || type(a:value_expected) != type('')
      return s:FALSE
    endif
    return eval('a:value_actual ' . a:expr_matcher . ' a:value_expected')
  else
    call s:ThrowInternalException(
    \   'InvalidOperation',
    \   {'message': 'Unknown matcher - ' . string(a:expr_matcher)}
    \ )
  endif
endfunction




function! s:generate_default_failure_message(i)  "{{{2
  return [
  \   '  Actual value: ' . vspec#pretty_string(a:i.value_actual),
  \   'Expected value: ' . vspec#pretty_string(a:i.value_expected),
  \ ]
endfunction




function! s:generate_failure_message(i)  "{{{2
  let matcher = get(s:custom_matchers, a:i.value_matcher, 0)
  if matcher is 0
    return s:generate_default_failure_message(a:i)
  else
    let method_name =
    \ a:i.value_not == ''
    \ ? 'failure_message_for_should'
    \ : 'failure_message_for_should_not'
    let Generate = get(
    \   matcher,
    \   method_name,
    \   0
    \ )
    if Generate is 0
      return s:generate_default_failure_message(a:i)
    else
      let values = [a:i.value_actual]
      if a:i.expr_expected != ''
        call extend(values, a:i.value_expected)
      endif
      let maybe_message = call(Generate, values, matcher)
      return
      \ type(maybe_message) == type('')
      \ ? [maybe_message]
      \ : maybe_message
    endif
  endif
endfunction




function! s:is_custom_matcher(expr_matcher)  "{{{2
  return a:expr_matcher =~# '^to'
endfunction




function! s:is_equality_matcher(expr_matcher)  "{{{2
  return 0 <= index(s:VALID_MATCHERS_EQUALITY, a:expr_matcher)
endfunction




function! s:is_matcher(expr_matcher)  "{{{2
  return 0 <= index(s:VALID_MATCHERS, a:expr_matcher) || s:is_custom_matcher(a:expr_matcher)
endfunction




function! s:is_negative_matcher(expr_matcher)  "{{{2
  " FIXME: Ad hoc way.
  return s:is_matcher(a:expr_matcher) && a:expr_matcher =~# '\(!\|not\)'
endfunction




function! s:is_orderable_type(value)  "{{{2
  " FIXME: +float
  return type(a:value) == type(0) || type(a:value) == type('')
endfunction




function! s:is_ordering_matcher(expr_matcher)  "{{{2
  return 0 <= index(s:VALID_MATCHERS_ORDERING, a:expr_matcher)
endfunction




function! s:is_regexp_matcher(expr_matcher)  "{{{2
  return 0 <= index(s:VALID_MATCHERS_REGEXP, a:expr_matcher)
endfunction




function! s:split_at_matcher(s)  "{{{2
  let tokens = matchlist(a:s, s:RE_SPLIT_AT_MATCHER)
  return tokens[1:4]
endfunction

let s:RE_SPLIT_AT_MATCHER =
\ printf(
\   '\C\v^(.{-})\s+%%((not)\s+)?(%%(%%(%s)[#?]?)|to\w+>)\s*(.*)$',
\   join(
\     map(
\       reverse(sort(copy(s:VALID_MATCHERS))),
\       'escape(v:val, "=!<>~#?")'
\     ),
\     '|'
\   )
\ )








" Tools  "{{{1
function! vspec#scope()  "{{{2
  return s:
endfunction




function! vspec#sid()  "{{{2
  return maparg('<SID>', 'n')
endfunction
nnoremap <SID>  <SID>








" __END__  "{{{1
" vim: foldmethod=marker
