defmodule FiresideWeb.Router do
  use FiresideWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FiresideWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", FiresideWeb do
    pipe_through :browser

    live "/", GuestbookLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", FiresideWeb do
  #   pipe_through :api
  # end
end
