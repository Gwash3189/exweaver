defmodule Exweaver.Schema do
  @moduledoc """
  Base schema for all Exweaver schemas.

  Sets `Exweaver.UUIDv7` as the primary- and foreign-key type (decisions.md D2)
  and uses `:utc_datetime` timestamps (`inserted_at` / `updated_at`, the Ecto
  defaults — see database_diagram.md).

  Use it in place of `use Ecto.Schema`:

      defmodule Exweaver.Accounts.Company do
        use Exweaver.Schema

        schema "companies" do
          field :name, :string
          timestamps()
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema

      @primary_key {:id, Exweaver.UUIDv7, autogenerate: true}
      @foreign_key_type Exweaver.UUIDv7
      @timestamps_opts [type: :utc_datetime]
    end
  end
end
