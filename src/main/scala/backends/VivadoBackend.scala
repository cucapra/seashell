package fuselang.backend

import Cpp._

import fuselang.common._
import Syntax._
import Configuration._
import CompilerError._

private class VivadoBackend extends CppLike {
  val CppPreamble: Doc = """
    |#include "ap_int.h"
  """.stripMargin.trim

  def unroll(n: Int): Doc = n match {
    case 1 => emptyDoc
    case n => value(s"#pragma HLS UNROLL factor=$n skip_exit_check") <@> line
  }

  def bank(id: Id, banks: List[Int]): String = banks.zipWithIndex.foldLeft(""){
    case (acc, (bank, dim)) =>
      if (bank != 1) {
        s"${acc}\n#pragma HLS ARRAY_PARTITION variable=$id cyclic factor=$bank dim=${dim + 1}"
      } else {
        acc
      }
  }

  def bankPragmas(decls: List[Decl]): List[Doc] = decls
    .collect({ case Decl(id, typ: TArray) => bank(id, typ.dims.map(_._2)) })
    .withFilter(s => s != "")
    .map(s => value(s))

  override def emitLet(let: CLet): Doc = {
    super.emitLet(let) <@>
    (let.typ match {
      case Some(t) => vsep(bankPragmas(List(Decl(let.id, t))))
      case None => emptyDoc
    })
  }

  def emitFor(cmd: CFor): Doc =
    "for" <> emitRange(cmd.range) <+> scope {
      unroll(cmd.range.u) <>
      cmd.par <>
      (if (cmd.combine != CEmpty) line <> text("// combiner:") <@> cmd.combine
       else emptyDoc)
    }

  def emitFuncHeader(func: FuncDef, entry: Boolean = false): Doc = {
    (if (entry)
      vsep(func.args.map(arg => text(s"#pragma HLS INTERFACE ap_memory port=${arg.id}")))
     else emptyDoc) <@>
    vsep(bankPragmas(func.args))
  }

  def emitArrayDecl(ta: TArray, id: Id) =
    emitType(ta.typ) <+> id <> generateDims(ta.dims)

  def generateDims(dims: List[(Int, Int)]): Doc =
    ssep(dims.map(d => brackets(value(d._1))), emptyDoc)

  def emitType(typ: Type) = typ match {
    case _:TVoid => "void"
    case _:TBool | _:TIndex | _:TStaticInt => "int"
    case _:TFloat => "float"
    case _:TDouble => "double"
    case TSizedInt(s, un) => if (un) s"ap_uint<$s>" else s"ap_int<$s>"
    case TArray(typ, _) => emitType(typ)
    case TRecType(n, _) => n
    case _:TFun => throw Impossible("Cannot emit function types")
    case TAlias(n) => n
  }

  def emitProg(p: Prog, c: Config): String = {
    val layout =
      CppPreamble <@>
      vsep(p.includes.map(emitInclude)) <@>
      vsep(p.defs.map(emitDef)) <@>
      vsep(p.decors.map(d => text(d.value))) <@>
      emitFunc(FuncDef(Id(c.kernelName), p.decls, Some(p.cmd)), true)

    super.pretty(layout).layout
  }

}

private class VivadoBackendHeader extends VivadoBackend {
  override def emitCmd(c: Command): Doc = emptyDoc

  override def emitFunc(func: FuncDef, entry: Boolean): Doc = func match { case FuncDef(id, args, _) =>
    val as = hsep(args.map(d => emitDecl(d.id, d.typ)), comma)
    "void" <+> id <> parens(as) <> semi
  }

  override def emitProg(p: Prog, c: Config) = {
    val declarations =
      vsep(p.includes.map(emitInclude) ++ p.defs.map(emitDef)) <@>
      emitFunc(FuncDef(Id(c.kernelName), p.decls, None))

    super.pretty(declarations).layout
  }
}

case object VivadoBackend extends Backend {
  def emitProg(p: Prog, c: Config) = c.header match {
    case true => (new VivadoBackendHeader()).emitProg(p, c)
    case false => (new VivadoBackend()).emitProg(p, c)
  }
  val canGenerateHeader = true
}
