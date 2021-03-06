(**
 * Copyright (c) 2013-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the "flow" directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 *)

module S = Ast.Statement;;
module E = Ast.Expression;;
module T = Ast.Type;;
module P = Ast.Pattern;;
module Utils = Flowtestgen_utils;;
module FRandom = Utils.FRandom;;

(* ESSENTIAL: Syntax type and related functions *)
type t =
  | Expr of E.t'
  | Stmt of S.t'
  | Empty

let str_of_syntax (s : t) : string =
  match s with
  | Expr e -> Utils.string_of_expr e
  | Stmt s -> Utils.string_of_stmt s
  | Empty -> ""

(* ESSENTIAL: functions for making syntax *)
let mk_expr_stmt (expr : E.t') : S.t' =
  S.Expression.(S.Expression {expression = (Loc.none, expr);
                              directive = None})

let mk_ret_stmt (expr : E.t') : t =
  Stmt (S.Return.(S.Return {argument = Some (Loc.none, expr)}))

let mk_func_def
    (fname : string)
    (pname : string)
    (ptype : T.t')
    (body : t list)
    (rtype : T.t') : t =

  let body =
    let open S.Block in
    let stmt_list = List.fold_left (fun acc s -> match s with
        | Stmt st -> (Loc.none, st) :: acc
        | Expr e -> (Loc.none, (mk_expr_stmt e)) :: acc
        | Empty -> acc) [] body in
    {body = stmt_list} in

  let param = let open P.Identifier in
    (Loc.none, P.Identifier {name = (Loc.none, pname);
                             typeAnnotation = Some (Loc.none, (Loc.none, ptype));
                             optional = false}) in

  let func = let open Ast.Function in
    {id = Some (Loc.none, fname);
     params = (Loc.none, { Params.params = [param]; rest = None });
     body = Ast.Function.BodyBlock (Loc.none, body);
     async = false;
     generator = false;
     predicate = None;
     expression = false;
     returnType = Some (Loc.none, (Loc.none, rtype));
     typeParameters = None} in
  Stmt (S.FunctionDeclaration func)

let mk_func_call (fid : E.t') (param : E.t') : t =
  Expr (E.Call.(E.Call {callee = (Loc.none, fid);
                        arguments = [E.Expression (Loc.none, param)]}))

let mk_literal (t : T.t') : t = match t with
  | T.Number ->
    let lit = Ast.Literal.({value = Number 1.1; raw = "1.1"}) in
    Expr (E.Literal lit)
  | T.String ->
    let lit = Ast.Literal.({value = String "foo"; raw = "\"foo\""}) in
    Expr (E.Literal lit)
  | _ -> failwith "Unsupported"

let mk_prop_read
    (obj_name : string)
    (prop_name : string) : t =
  let open E.Member in
  Expr (E.Member {_object = (Loc.none, E.Identifier (Loc.none, obj_name));
                  property = PropertyIdentifier (Loc.none, prop_name);
                  computed = false})

let mk_prop_write
    (oname : string)
    (pname : string)
    (expr : E.t') : t =
  let read = match mk_prop_read oname pname with
    | Expr e -> e
    | _ -> failwith "This has to be an expression" in
  let left = P.Expression (Loc.none, read) in
  let right = expr in
  let assign =
    let open E.Assignment in
    E.Assignment {operator = Assign;
                  left = (Loc.none, left);
                  right = (Loc.none, right)} in
  Stmt (mk_expr_stmt assign)

let mk_vardecl ?etype (vname : string) (expr : E.t') : t =
  (* Make an identifier *)
  let t = match etype with
    | None -> None
    | Some t -> Some (Loc.none, (Loc.none, t)) in

  let id = let open P.Identifier in
    (Loc.none, P.Identifier
       { name = (Loc.none, vname);
         typeAnnotation = t;
         optional = false}) in

  (* get the expression and its dependencies *)
  let init = expr in

  (* Make a var declaration *)
  let decl = let open S.VariableDeclaration.Declarator in
    (Loc.none, {id; init = Some (Loc.none, init)}) in
  let var_decl = let open S.VariableDeclaration in
    {declarations = [decl]; kind = Var} in

  Stmt (S.VariableDeclaration var_decl)

let mk_obj_lit (plist : (string * (E.t' * T.t')) list) : t =
  let props = List.map (fun p ->
      let pname = fst p in
      let expr = fst (snd p) in
      let open E.Object.Property in
      E.Object.Property (Loc.none, {key = Identifier (Loc.none, pname);
                                    value = Init (Loc.none, expr);
                                    _method = false;
                                    shorthand = false})) plist in
  let open E.Object in
  Expr (E.Object {properties = props})
