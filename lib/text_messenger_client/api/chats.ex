defmodule TextMessengerClient.ChatsAPI do
  alias HTTPoison
  import TextMessengerClient.RequestHandler
  alias TextMessengerClient.Protobuf.Chats

  def fetch_chats(token) do
    api_url = Application.get_env(:text_messenger_client, :api_url)
    endpoint_url = "#{api_url}/chats"

    with {:ok, body} <- fetch_request(endpoint_url, token) do
      Chats.decode(body)
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
