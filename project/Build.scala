// vim: filetype=scala shiftwidth=2 softtabstop=2 expandtab
import sbt._
import Keys._
import flex2.tools.oem.Library
import flex2.tools.oem.Message

object Box2DFlashBuild extends Build {
  lazy val flexSource = SettingKey[File]("flex-source")

  lazy val compcBuilder =
    TaskKey[Library]("compc-builder", "Create a builder for SWC compilation.")

  lazy val compcDirectory =
    SettingKey[File]("compc-directory", "Output directory of SWC content.")

  lazy val compc = TaskKey[File]("compc", "Generate SWC content.")

  lazy val packageSwc =
    TaskKey[File]("package-swc", "Create SWC file from content.")

  lazy val rsl = TaskKey[File]("rsl", "Extract runtime shared library of SWC.")

  private def packageSwcMappings = compc map { d =>
    Seq(d / "library.swf" -> "library.swf",
        d / "catalog.xml" -> "catalog.xml")
  }

  def compcSettings = Seq(
    includeFilter in unmanagedSources := GlobFilter("*.as"),
    unmanagedSourceDirectories <+= flexSource,
    cacheDirectory <<= cacheDirectory { _ / "compc" },
    compcBuilder in Defaults.TaskGlobal <<=
      (sourceDirectories, sources, compcDirectory) map {
      (sd, s, out) =>
      val lib = new Library
      val config = lib.getDefaultConfiguration()
      config.compress(false)
      config.addSourcePath((
      for {
        p <- sd
        if p.exists
      } yield {
        p
      })(collection.breakOut))
      lib.setConfiguration(config)
      lib.setDirectory(out)
      s foreach lib.addComponent
      lib
    },
    compc in Defaults.TaskGlobal <<= (compcBuilder, cacheDirectory in compc,
                                      streams, baseDirectory) map {
      (lib, c, s, bd) =>
      val originContextClassLoader =
        Thread.currentThread.getContextClassLoader
      Thread.currentThread.setContextClassLoader(getClass.getClassLoader)
      try {
        var errorCount = 0
        lib.setLogger(new flex2.tools.oem.Logger {
          override def log(message: Message, errorCode: Int, source: String) {
            s.log.log(
              message.getLevel match {
                case Message.INFO => Level.Info
                case Message.WARNING => Level.Warn
                case Message.ERROR =>
                  errorCount += 1
                  Level.Error
              },
              (message.getPath match {
                case null => ""
                case p => p + ":"
              }) +
              (message.getLine match {
                case -1 => ""
                case l => l + ":"
              }) +
              (message.toString match {
                case null => ""
                case s => s
              })
            )
          }
        })
        import java.io._
        if (c.exists) {
          val is = new BufferedInputStream(new FileInputStream(c))
          try { lib.load(is) } finally { is.close() }
        } else if (!c.getParentFile.exists) {
          c.getParentFile.mkdirs()
        }
        lib.build(true)
        val os = new BufferedOutputStream(new FileOutputStream(c))
        try { lib.save(os) } finally { os.close() }
        if (errorCount > 0) {
          error("Failed to compc " + lib.getDirectory)
        } else {
          lib.getDirectory
        }
      } finally {
        Thread.currentThread.setContextClassLoader(originContextClassLoader)
      }
    }
  )

  val flexSettings =
    inTask(compc)(Defaults.sourceConfigPaths) ++
    inTask(compc)(compcSettings) ++
    Seq(
      compcDirectory <<= target { _ / "compc" },
      flexSource <<= sourceDirectory { _ / "flex"},
      cacheDirectory in rsl <<= (cacheDirectory in rsl) { _ / "rsl" },
      artifact in packageSwc <<= artifact {
        _.copy(`type` = "swc", extension = "swc")
      },
      packageBin <<= packageSwc,
      rsl <<= compc map { _ / "library.swf" },
      // TODO: ASDoc
      unmanagedSourceDirectories in packageSrc <+= flexSource
    ) ++
    Defaults.packageTasks(packageSwc, packageSwcMappings)

  val defaultConfigs = inConfig(Compile)(flexSettings) ++
    addArtifact(artifact in packageSwc in Compile, packageSwc in Compile) ++
    addArtifact(artifact {
      _.copy(`type` = "swf", extension = "swf")
    }, rsl in Compile)

  lazy val root = Project(id = "box2dflash",
                          base = file("."),
                          settings = Project.defaultSettings ++ defaultConfigs)
}
