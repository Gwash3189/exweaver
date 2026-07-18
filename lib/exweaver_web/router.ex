defmodule ExweaverWeb.Router do
  use ExweaverWeb, :router

  alias ExweaverWeb.Plugs

  pipeline :api do
    plug :accepts, ["json"]
  end

  # personal-token-only management endpoints (companies, customers, flags, ...)
  pipeline :management do
    plug Plugs.BearerAuth
    plug Plugs.RequirePersonal
    plug Plugs.Authorize
  end

  # sdk-key-only evaluation endpoints
  pipeline :evaluation do
    plug Plugs.BearerAuth
    plug Plugs.RequireSdk
  end

  scope "/api/v1", ExweaverWeb do
    pipe_through :api

    post "/auth/signup", AuthController, :signup
    post "/auth/login", AuthController, :login
  end

  # C10/C10a: companies, customers, environments, flags, access_keys, roles
  scope "/api/v1", ExweaverWeb do
    pipe_through [:api, :management]

    get "/environments", EnvironmentController, :index
    post "/environments", EnvironmentController, :create
    patch "/environments/:id", EnvironmentController, :update
    delete "/environments/:id", EnvironmentController, :delete

    get "/flags", FlagController, :index
    post "/flags", FlagController, :create
    get "/flags/:id", FlagController, :show
    patch "/flags/:id", FlagController, :update
    delete "/flags/:id", FlagController, :delete

    get "/flags/:flag_id/environments/:environment_id/state", FlagStateController, :show
    put "/flags/:flag_id/environments/:environment_id/state", FlagStateController, :update

    get "/flags/:flag_id/environments/:environment_id/assignments",
        FlagAssignmentController,
        :index

    put "/flags/:flag_id/environments/:environment_id/assignments/:end_user_id",
        FlagAssignmentController,
        :update

    delete "/flags/:flag_id/environments/:environment_id/assignments/:end_user_id",
           FlagAssignmentController,
           :delete

    get "/end_users", EndUserController, :index
    post "/end_users", EndUserController, :create
    delete "/end_users/:id", EndUserController, :delete

    post "/companies", CompanyController, :create

    get "/customers", CustomerController, :index
    post "/customers", CustomerController, :create
    patch "/customers/:id", CustomerController, :update
    post "/customers/:id/reset", CustomerController, :reset
    delete "/customers/:id", CustomerController, :delete

    get "/access_keys", AccessKeyController, :index
    post "/access_keys", AccessKeyController, :create
    delete "/access_keys/:id", AccessKeyController, :delete

    get "/roles", RoleController, :index
  end

  # C11: GET /evaluate, GET /evaluate/:flag_key
  scope "/api/v1", ExweaverWeb do
    pipe_through [:api, :evaluation]

    get "/evaluate", EvaluateController, :index
    get "/evaluate/:flag_key", EvaluateController, :show
  end
end
