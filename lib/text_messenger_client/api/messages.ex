defmodule TextMessengerClient.MessagesAPI do
  alias HTTPoison
  import TextMessengerClient.RequestHandler
  alias TextMessengerClient.Protobuf.ChatMessages

  def fetch_messages(token, id) do
    api_url = Application.get_env(:text_messenger_client, :api_url)
    endpoint_url = "#{api_url}/chats/#{id}/messages"

    with {:ok, body} <- fetch_request(endpoint_url, token) do
      ChatMessages.decode(body)
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
