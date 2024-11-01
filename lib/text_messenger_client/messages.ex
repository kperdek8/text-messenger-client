defmodule TextMessengerClient.MessagesAPI do
  alias HTTPoison
  import TextMessengerClient.RequestHandler

  # TODO: Handle 404
  def fetch_messages(id) when is_integer(id) do
    api_url = Application.get_env(:text_messenger_client, :api_url)
    endpoint_url = "#{api_url}/chats/#{id}/messages"

    with {:ok, body} <- fetch_request(endpoint_url) do
      ChatMessages.decode(body)
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
