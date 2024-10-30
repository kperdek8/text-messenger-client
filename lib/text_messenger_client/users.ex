defmodule TextMessengerClient.Users do
  alias HTTPoison
  import TextMessengerClient.RequestHandler

  def fetch_users() do
    api_url = Application.get_env(:text_messenger_client, :api_url)
    endpoint_url = "#{api_url}/users"

    with {:ok, body} <- fetch_request(endpoint_url) do
      Users.decode(body)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # TODO: Handle 404
  def fetch_user(id) when is_integer(id) do
    api_url = Application.get_env(:text_messenger_client, :api_url)
    endpoint_url = "#{api_url}/users/#{id}"

    with {:ok, body} <- fetch_request(endpoint_url) do
      User.decode(body)
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
