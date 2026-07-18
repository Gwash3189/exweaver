defmodule ExweaverWeb.EvaluateController do
  @moduledoc """
  Sdk-key-only evaluation endpoints (rest_api.md, evaluation.md). The
  environment comes from `current_environment`, assigned by `BearerAuth` from
  the sdk key — never a request param.
  """

  use ExweaverWeb, :controller

  alias Exweaver.Evaluation
  alias ExweaverWeb.FallbackController

  def index(conn, params) do
    flags = Evaluation.evaluate_all(conn.assigns.current_environment, params["end_user"])
    json(conn, %{flags: flags})
  end

  def show(conn, %{"flag_key" => flag_key} = params) do
    case Evaluation.evaluate_one(conn.assigns.current_environment, flag_key, params["end_user"]) do
      {:ok, value} -> json(conn, %{flags: %{flag_key => value}})
      {:error, reason} -> FallbackController.call(conn, {:error, reason})
    end
  end
end
