unmanagedJars in Compile ++= {
  file(System.getenv("FLEX_HOME")) / "lib" ** "*.jar" classpath;
}
