defmodule ExweaverCli.ApiError do
  @moduledoc """
  A normalized client-side error.

  Wraps every failure the client can produce behind one shape: server error
  responses (`{"error": {"code", "message"}}`), transport failures, and the
  local "no server configured" case. `code` mirrors the server's snake_case
  error code where there is one, or a synthesized code otherwise.
  """

  @enforce_keys [:code]
  defstruct status: nil, code: nil, message: nil

  @type t :: %__MODULE__{
          status: non_neg_integer() | nil,
          code: String.t(),
          message: String.t() | nil
        }
end
