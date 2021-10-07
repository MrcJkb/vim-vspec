vim9script
# vspec - Testing framework for Vim script
# Version: 1.9.2
# Copyright (C) 2009-2021 Kana Natsuno <https://whileimautomaton.net/>
# License: MIT license  {{{
#     Permission is hereby granted, free of charge, to any person obtaining
#     a copy of this software and associated documentation files (the
#     "Software"), to deal in the Software without restriction, including
#     without limitation the rights to use, copy, modify, merge, publish,
#     distribute, sublicense, and/or sell copies of the Software, and to
#     permit persons to whom the Software is furnished to do so, subject to
#     the following conditions:
#
#     The above copyright notice and this permission notice shall be included
#     in all copies or substantial portions of the Software.
#
#     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
#     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
#     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
#     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
#     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
#     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
# }}}

# Misc. utilities  # {{{1
export def ParseString(string_expression: string): any  # {{{2
  const s = substitute(string_expression, '^\s*\(.\{-}\)\s*$', '\1', '')
  if !(s =~ '^''\(''''\|[^'']\)*''$' || s =~ '^"\(\\.\|[^"]\)*"$')
    ThrowInternalException('SyntaxError', {message: 'Invalid string - ' .. string(s)})
  endif
  return eval(s)
enddef

export def ThrowInternalException(type: string, values: any): void  # {{{2
  throw printf('vspec:%s:%s', type, string(values))
enddef

# __END__  # {{{1
# vim: foldmethod=marker
