# Used by "mix format"
[
  plugins: [Volt.Formatter],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}", "priv/**/*.{js,ts,jsx,tsx}"],
  volt: [
    trailing_comma: :none,
    tab_width: 2,
    semi: false,
    single_quote: true,
    print_width: 100,
    arrow_parens: :always
  ]
]
