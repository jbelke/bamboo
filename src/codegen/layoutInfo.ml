type layout_info =
  { (* The initial calldata is organized like this: *)
    (* |constructor code|runtime code|constructor arguments|  *)
    init_data_size : Assoc.contract_id (* Which contract is initially active *) -> int
  ; constructor_code_size : Assoc.contract_id -> int
    (* runtime_coode_offset is equal to constructor_code_size *)
  ; runtime_code_size : int
  ; contract_offset_in_runtime_code : Assoc.contract_id -> int

    (* And then, the runtime code is organized like this: *)
    (* |dispatcher that jumps into the current pc|dispatcher that jumps into current contract|runtime code for contract A|runtime code for contract B|runtime code for contract C| *)

    (* And then, the runtime code for a particular contract is organized like this: *)
    (* |dispatcher that jumps into a runtime case|runtime code for case f|runtime code for case g| *)

    (* numbers about the storage *)
    (* The storage during the runtime looks like this: *)
    (* |current pc (zero means none)|entry_pc_of_current_contract|pod contract argument0|pod contract argument1| *)
    (* In addition, array elements are placed at the same location as in Solidity *)

  ; storage_current_pc_index : int
  ; storage_constructor_arguments_begin : Assoc.contract_id -> int
  ; storage_constructor_arguments_size : Assoc.contract_id -> int
  }

type contract_layout_info =
  { contract_constructor_code_size : int
  ; contract_argument_size : int
  (** the number of words that the contract arguments occupy *)
  }

let compute_constructor_code_size lst cid =
  let c : contract_layout_info = Assoc.choose_contract cid lst in
  c.contract_constructor_code_size

let compute_runtime_code_size lst = failwith "runtime_code_size"
let compute_constructor_arguments_size lst cid = failwith "constructor_arguments_size"

let compute_init_data_size lst cid =
  compute_constructor_code_size lst cid +
    compute_runtime_code_size lst +
    compute_constructor_arguments_size lst cid

let construct_layout_info (lst : (Assoc.contract_id * contract_layout_info) list) : layout_info =
  { init_data_size = compute_init_data_size lst
  ; constructor_code_size = compute_constructor_code_size lst
  ; runtime_code_size = compute_runtime_code_size lst
  ; contract_offset_in_runtime_code = failwith "contract_offset_in_runtime_code"
  ; storage_current_pc_index = failwith "storage_current_pc_index"
  ; storage_constructor_arguments_begin = failwith "storage_constructor_arguments_begin"
  ; storage_constructor_arguments_size = compute_constructor_arguments_size lst
  }

(* Assuming the layout described above, this definition makes sense. *)
let runtime_code_offset (layout : layout_info) (cid : Assoc.contract_id) : int =
  layout.constructor_code_size cid

let rec realize_pseudo_imm (layout : layout_info) (initial_cid : Assoc.contract_id) (p : PseudoImm.pseudo_imm) : Big_int.big_int =
  PseudoImm.(
  match p with
  | Big b -> b
  | Int i -> Big_int.big_int_of_int i
  | DestLabel l ->
     failwith "realize_pseudo_imm: destlabel"
  | ContractId cid ->
     failwith "realize_pseudo_imm: should be a pc or an id itself or a signature?"
  | StorageProgramCounterIndex ->
     Big_int.big_int_of_int (layout.storage_current_pc_index)
  | StorageConstructorArgumentsBegin cid ->
     Big_int.big_int_of_int (layout.storage_constructor_arguments_begin cid)
  | StorageConstructorArgumentsSize cid ->
     Big_int.big_int_of_int (layout.storage_constructor_arguments_size cid)
  | InitDataSize cid ->
     Big_int.big_int_of_int (layout.init_data_size cid)
  | RuntimeCodeOffset ->
     Big_int.big_int_of_int (runtime_code_offset layout initial_cid)
  | RuntimeCodeSize ->
     Big_int.big_int_of_int (layout.runtime_code_size)
  | ContractOffsetInRuntimeCode cid ->
     Big_int.big_int_of_int (layout.contract_offset_in_runtime_code cid)
  | CaseOffsetInRuntimeCode (cid, case_header) ->
     failwith "realize_pseudo_imm caseoffset"
  | Minus (a, b) ->
     Big_int.sub_big_int (realize_pseudo_imm layout initial_cid a) (realize_pseudo_imm layout initial_cid b)
  )

let realize_pseudo_instruction (l : layout_info) (initial_cid : Assoc.contract_id) (i : PseudoImm.pseudo_imm Evm.instruction)
    : Big_int.big_int Evm.instruction =
  Evm.(
  match i with
  | PUSH1 imm -> PUSH1 (realize_pseudo_imm l initial_cid imm)
  | PUSH32 imm -> PUSH32 (realize_pseudo_imm l initial_cid imm)
  | NOT -> NOT
  | TIMESTAMP -> TIMESTAMP
  | EQ -> EQ
  | ISZERO -> ISZERO
  | LT -> LT
  | GT -> GT
  | BALANCE -> BALANCE
  | STOP -> STOP
  | ADD -> ADD
  | MUL -> MUL
  | SUB -> SUB
  | DIV -> DIV
  | SDIV -> SDIV
  | MOD -> MOD
  | SMOD -> SMOD
  | ADDMOD -> ADDMOD
  | MULMOD -> MULMOD
  | EXP -> EXP
  | SIGNEXTEND -> SIGNEXTEND
  | ADDRESS -> ADDRESS
  | ORIGIN -> ORIGIN
  | CALLER -> CALLER
  | CALLVALUE -> CALLVALUE
  | CALLDATALOAD -> CALLDATALOAD
  | CALLDATASIZE -> CALLDATASIZE
  | CALLDATACOPY -> CALLDATACOPY
  | CODESIZE -> CODESIZE
  | CODECOPY -> CODECOPY
  | GASPRICE -> GASPRICE
  | EXTCODESIZE -> EXTCODESIZE
  | EXTCODECOPY -> EXTCODECOPY
  | POP -> POP
  | MLOAD -> MLOAD
  | MSTORE -> MSTORE
  | MSTORE8 -> MSTORE8
  | SLOAD -> SLOAD
  | SSTORE -> SSTORE
  | JUMP -> JUMP
  | JUMPI -> JUMPI
  | PC -> PC
  | MSIZE -> MSIZE
  | GAS -> GAS
  | JUMPDEST l -> JUMPDEST l
  | LOG0 -> LOG0
  | LOG1 -> LOG1
  | LOG2 -> LOG2
  | LOG3 -> LOG3
  | LOG4 -> LOG4
  | CREATE -> CREATE
  | CALL -> CALL
  | CALLCODE -> CALLCODE
  | RETURN -> RETURN
  | DELEGATECALL -> DELEGATECALL
  | SUICIDE -> SUICIDE
  | SWAP1 -> SWAP1
  | SWAP2 -> SWAP2
  | SWAP3 -> SWAP3
  | SWAP4 -> SWAP4
  | SWAP5 -> SWAP5
  | SWAP6 -> SWAP6
  | DUP1 -> DUP1
  | DUP2 -> DUP2
  | DUP3 -> DUP3
  | DUP4 -> DUP4
  | DUP5 -> DUP5
  | DUP6 -> DUP6
  | DUP7 -> DUP7
  )

let realize_pseudo_program (l : layout_info) (initial_cid : Assoc.contract_id) (p : PseudoImm.pseudo_imm Evm.program)
    : Big_int.big_int Evm.program
  = List.map (realize_pseudo_instruction l initial_cid) p

let layout_info_of_contract (c : Syntax.typ Syntax.contract) (constructor_code : PseudoImm.pseudo_imm Evm.program) =
  { contract_constructor_code_size = Evm.size_of_program constructor_code
  ; contract_argument_size  = Ethereum.total_size_of_interface_args (List.map snd (Ethereum.constructor_arguments c)) }
