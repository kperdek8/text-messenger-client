defmodule TextMessengerClientWeb.UserSessionController do
  use TextMessengerClientWeb, :controller

  def login(conn, %{"token" => token}) do
    conn
    |> put_session(:token, Base.url_encode64(token))
    |> redirect(to: ~p"/")
  end

  def logout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: "/login")
  end
end
