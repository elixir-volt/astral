import Config

config :volt, :format,
  print_width: 100,
  semi: true,
  single_quote: false,
  trailing_comma: :all,
  arrow_parens: :always

config :volt, :lint,
  plugins: [:typescript],
  tsgolint: System.find_executable("tsgolint"),
  rules: %{
    "correctness" => :deny,
    "no-debugger" => :deny,
    "eqeqeq" => :deny,
    "typescript/no-explicit-any" => :warn
  }
