(**************************************************************************)
(*  This file is part of BINSEC.                                          *)
(*                                                                        *)
(*  Copyright (C) 2016-2025                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  you can redistribute it and/or modify it under the terms of the GNU   *)
(*  Lesser General Public License as published by the Free Software       *)
(*  Foundation, version 2.1.                                              *)
(*                                                                        *)
(*  It is distributed in the hope that it will be useful,                 *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *)
(*  GNU Lesser General Public License for more details.                   *)
(*                                                                        *)
(*  See the GNU Lesser General Public License version 2.1                 *)
(*  for more details (enclosed in the file licenses/LGPLv2.1).            *)
(*                                                                        *)
(**************************************************************************)

include Cli.Options (struct
  let name = "ppc64"
  let shortname = name
end)

module Parser = Unisim_helper.Make (Logger)

let decode addr bytes = Ppc64dba.decode ~addr bytes |> Parser.parse_message

let decode_from_reader (addr : Virtual_address.t) reader =
  if (addr :> int) mod 4 <> 0 then
    (Unisim_helper.empty_instruction, Unisim_helper.die)
  else
    match Lreader.Read.i32 reader with
    | exception _ -> (Unisim_helper.empty_instruction, Unisim_helper.die)
    | bytes ->
        let ins, dhunk, status = decode (Virtual_address.to_int64 addr) bytes in
        (match status with
        | None ->
            Lreader.rewind reader (4 - Size.Byte.to_int ins.size);
            Parser.incr_success ins.opcode
        | Some Undefined ->
            Lreader.rewind reader 4;
            Parser.incr_error Undefined (Format.sprintf "%08lx" bytes)
        | Some err ->
            Lreader.rewind reader (4 - Size.Byte.to_int ins.size);
            Parser.incr_error err ins.opcode);
        (ins, dhunk)

let decode reader addr =
  let res = decode_from_reader addr reader in
  Logger.debug ~level:5 "@[%a@]" Dhunk.pp (snd res);
  Logger.debug ~level:3 "@[%a@]" Parser.pp_statistics ();
  res

let cached_decode reader =
  let h = Virtual_address.Htbl.create 7 in
  fun (addr : Virtual_address.t) ->
    match Virtual_address.Htbl.find h addr with
    | res -> res
    | exception Not_found ->
        let res = decode reader addr in
        Virtual_address.Htbl.add h addr res;
        res

let () =
  Disasm_core.register_decoder (Machine.ppc64 BigEndian) cached_decode Fun.id
