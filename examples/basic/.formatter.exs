[
  plugins: [Volt.Formatter],
  inputs: [
    "{mix,.formatter}.exs",
    "{config,lib,test}/**/*.{ex,exs}",
    "assets/app.ts",
    "assets/env.d.ts",
    "assets/islands/**/*.{js,ts,jsx,tsx}"
  ],
  volt: [
    print_width: 100,
    semi: true,
    single_quote: false,
    trailing_comma: :all,
    arrow_parens: :always
  ]
]
