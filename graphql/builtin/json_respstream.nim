# nim-graphql
# Copyright (c) 2021 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  faststreams/[outputs, textio],
  ../common/respstream

export respstream

type
  State = enum
    StateTop
    StateBeginList
    StateList
    StateBeginMap
    StateMap

  JsonRespStream* = ref object of RootRef
    stream: OutputStream
    stack: seq[State]

template top(x: seq[State]): State =
  x[^1]

template top(x: seq[State], s: State) =
  x[^1] = s

template append(s: untyped) =
  x.stream.write s

proc beginList*(x: JsonRespStream) =
  if x.stack.top == StateList:
    append ','
  append '['
  x.stack.add StateBeginList

proc endList*(x: JsonRespStream) =
  discard x.stack.pop
  append ']'

proc beginMap*(x: JsonRespStream) =
  if x.stack.top == StateList:
    append ','
  append '{'
  x.stack.add StateBeginMap

proc endMap*(x: JsonRespStream) =
  discard x.stack.pop
  append '}'

proc writeSeparator(x: JsonRespStream) =
  let top = x.stack.top
  case top
  of StateList:
    append ','
  of StateBeginList:
    x.stack.top(StateList)
  else: discard

proc writeString*(x: JsonRespStream, v: string) =
  writeSeparator(x)
  append '\"'

  template addPrefixSlash(c) =
    append '\\'
    append c

  for c in v:
    case c
    of '\L': addPrefixSlash 'n'
    of '\b': addPrefixSlash 'b'
    of '\f': addPrefixSlash 'f'
    of '\t': addPrefixSlash 't'
    of '\r': addPrefixSlash 'r'
    of '"' : addPrefixSlash '\"'
    of '\0'..'\7':
      append "\\u000"
      append char(ord('0') + ord(c))
    of '\14'..'\31':
      append "\\u00"
      x.stream.writeHex([c])
    of '\\': addPrefixSlash '\\'
    else: append c

  append '\"'

proc writeBool*(x: JsonRespStream, v: bool) =
  writeSeparator(x)
  if v:
    append "true"
  else:
    append "false"

proc writeInt*(x: JsonRespStream, v: int) =
  writeSeparator(x)
  x.stream.writeText int64(v)

proc writeFloat*(x: JsonRespStream, v: float64) =
  writeSeparator(x)
  # TODO: implement write float
  append $v

proc writeNull*(x: JsonRespStream) =
  writeSeparator(x)
  append "null"

proc fieldName*(x: JsonRespStream, v: string) =
  let top = x.stack.top
  case top
  of StateMap:
    append ','
    append '\"'
    append v
    append '\"'
    append ':'
  of StateBeginMap:
    append '\"'
    append v
    append '\"'
    append ':'
    x.stack.top(StateMap)
  else:
    doAssert(false)

proc getOutput*(x: JsonRespStream): string =
  x.stream.getOutput(string)

proc newJsonRespStream*(): RespStream =
  let v = JsonRespStream(
    stream: memoryOutput(),
    stack: @[StateTop]
  )
  respStream(v)
