import Config

config :mdex_native, syntax_highlighter: :lumis

config :playwright, :test,
  trace: :retain_on_failure,
  screenshot: :only_on_failure,
  expect: [timeout: 15_000]
