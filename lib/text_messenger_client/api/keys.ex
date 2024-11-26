defmodule TextMessengerClient.KeysAPI do
  alias HTTPoison
  import TextMessengerClient.RequestHandler
  alias TextMessengerClient.Protobuf.{GroupKeys, UserKeys, UserKeysList}

  def post_encryption_key(token, key) do
    base64_key = Base.encode64(key)

    api_url = Application.get_env(:text_messenger_client, :api_url)
    endpoint_url = "#{api_url}/keys/encryption"
    params = %{"key" => base64_key}

    with {:ok, 200, body} <- post_request(endpoint_url, Jason.encode!(params), token) do
      {:ok, body}
    else
      {:ok, status_code, error} when status_code != 200 -> {:error, error}
      {:error, reason} -> {:error, reason}
    end
  end

  def post_signature_key(token, key) do
    base64_key = Base.encode64(key)

    api_url = Application.get_env(:text_messenger_client, :api_url)
    endpoint_url = "#{api_url}/keys/signature"
    params = %{"key" => base64_key}

    with {:ok, 200, body} <- post_request(endpoint_url, Jason.encode!(params), token) do
      {:ok, body}
    else
      {:ok, status_code, error} when status_code != 200 -> {:error, error}
      {:error, reason} -> {:error, reason}
    end
  end

  def fetch_members_keys(token, id) do
    api_url = Application.get_env(:text_messenger_client, :api_url)
    endpoint_url = "#{api_url}/chats/#{id}/users/keys"

    with {:ok, body} <- fetch_request(endpoint_url, token) do
      UserKeysList.decode(body)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def fetch_group_keys(token, id) do
    api_url = Application.get_env(:text_messenger_client, :api_url)
    endpoint_url = "#{api_url}/chats/#{id}/messages/keys"

    with {:ok, body} <- fetch_request(endpoint_url, token) do
      GroupKeys.decode(body)
    else
      {:error, reason} -> {:error, reason}
    end
  end


  def fetch_user_keys(token, id) do
    api_url = Application.get_env(:text_messenger_client, :api_url)
    endpoint_url = "#{api_url}/users/#{id}/keys"

    with {:ok, body} <- fetch_request(endpoint_url, token) do
      UserKeys.decode(body)
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
