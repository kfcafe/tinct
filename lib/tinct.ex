defmodule Tinct do
  @moduledoc """
  A terminal UI framework for Elixir.

  Tinct brings the Elm Architecture to terminal interfaces — declarative views,
  CSS-like styling, flexbox layout, and OTP supervision. Build terminal apps
  the same way you'd build a LiveView.

  ## Quick Start

      defmodule MyApp do
        use Tinct.Component

        def init(_opts), do: %{count: 0}

        def update(model, :increment), do: %{model | count: model.count + 1}
        def update(model, :decrement), do: %{model | count: model.count - 1}
        def update(model, {:key, "q"}), do: Tinct.quit(model)
        def update(model, _msg), do: model

        def view(model) do
          import Tinct.UI

          column do
            text "Count: \#{model.count}", bold: true
            text "↑/↓ to change, q to quit", color: :dark_gray
          end
        end
      end

      Tinct.run(MyApp)
  """
end
