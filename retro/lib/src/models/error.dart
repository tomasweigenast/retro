/// OnError specifies the possible ways of handle an unexpected error in a Repository
enum OnError {
  /// The exception will be rethrown
  rethrowEx,

  /// The exception will be ignored and the method will simply return
  ignore
}
