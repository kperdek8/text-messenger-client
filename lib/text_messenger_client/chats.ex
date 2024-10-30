defmodule TextMessengerClient.Chats do
  alias HTTPoison
  import TextMessengerClient.RequestHandler

  def fetch_chats() do
    api_url = Application.get_env(:text_messenger_client, :api_url)
    endpoint_url = "#{api_url}/chats"

    with {:ok, body} <- fetch_request(endpoint_url) do
      Chats.decode(body)
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
