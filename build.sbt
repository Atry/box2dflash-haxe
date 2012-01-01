// vim: filetype=scala shiftwidth=2 softtabstop=2 expandtab

addArtifact(artifact { _.copy(`type` = "haxepatch", extension = "haxepatch") },
baseDirectory map { _ / "box2dflash-haxe.haxepatch" })

managedSourceDirectories in Compile in compc <+= target / "haxe-compatible"

sourceGenerators in Compile in compc <+=
  (target, baseDirectory, cacheDirectory) {
  (t, bd, cd) =>
  val origin = bd / "Source"
  val renamed = t / "haxe-compatible"
  def renamePackage(input: String): String = input.head.toLower + input.tail
  def renameClass(input: String): String = input.capitalize
  def getOutputDirectoryName(input: File): File = {
    if (input == origin) {
      renamed
    } else {
      getOutputDirectoryName(input.getParentFile) / renamePackage(input.getName)
    }
  }
  def getOutputFileName(input: File): File = {
    if (input.getName.endsWith(".as")) {
      getOutputDirectoryName(input.getParentFile) / renameClass(input.getName)
    } else {
      getOutputDirectoryName(input)
    }
  }
  def generate(input: File, output: File) {
    if (input.getName.endsWith(".as")) {
      import java.nio.charset.Charset
      val inputContent = IO.read(input, Charset.forName("UTF-8"))
      val reg = """\bimport\s+((?:[A-Z]\w+\.)*+)|\bb2([A-Za-z])|\bpackage\s+([\w\.]++)\s*\{""".r
      val packageReg = """\b[A-Z]""".r
      IO.write(output, reg.replaceAllIn(inputContent, { m =>
        m.subgroups match {
          case List(g1, null, null) =>
            "import " + packageReg.replaceAllIn(g1, { _.group(0).toLowerCase })
          case List(null, g2, null) =>
            "B2" + g2
          case List(null, null, g3) =>
            "package " +
            packageReg.replaceAllIn(g3, { _.group(0).toLowerCase }) +
            " {"
          case _ => error("Invalid matching: " + m)
        }
      }), Charset.forName("UTF-8"))
    } else {
      output.mkdir()
    }
  }
  val generateHaXeCompatibleSource =
    FileFunction.cached(cd / "haxe-compatible")(FilesInfo.lastModified,
                                                FilesInfo.exists) { (in, out) =>
      for {
        i <- in.removed.toSeq.sorted.seq.reverseIterator
        val o = getOutputFileName(i)
        if out.unmodified.contains(o) ||
        out.modified.contains(o)
      } yield {
        o.delete()
        o
      }
      (for (i <- in.checked.toSeq.sorted.seq) yield {
        val o = getOutputFileName(i)
        if (!in.unmodified.contains(i) || !out.unmodified.contains(o)) {
          generate(i, o)
        }
        o
      })(collection.breakOut)
    }
  task {
    generateHaXeCompatibleSource(origin.***.get toSet) toSeq
  }
}

crossPaths := false

name := "box2dflash-haxe"

organization := "org.box2dflash"

version := "2.1a"
