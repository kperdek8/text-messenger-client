defmodule TextMessengerClient.UsersAPI do
  alias HTTPoison
  import TextMessengerClient.RequestHandler
  alias TextMessengerClient.Protobuf.{Users, User}

  # TODO: Separate login/register as AuthAPI

  def login(username, password) do
    api_url = Application.get_env(:text_messenger_client, :api_url)
    params = URI.encode_query(%{username: username, password: password})
    endpoint_url = "#{api_url}/users/login/?#{params}"
    with {:ok, 200, %{"token" => token, "username" => username, "user_id" => user_id}} <- post_request(endpoint_url, "") do
      {:ok, {token, username, user_id}}
    else
      {:ok, status_code, error} when status_code != 200 -> {:error, error}
      {:error, reason} -> {:error, reason}
    end
  end

  def register(username, password) do
    api_url = Application.get_env(:text_messenger_client, :api_url)
    params = URI.encode_query(%{username: username, password: password})
    endpoint_url = "#{api_url}/users/register/?#{params}"
    with {:ok, 201, %{"message" => message, "username" => _username}} <- post_request(endpoint_url, "") do
      {:ok, message}
    else
      {:ok, 422, %{"details" => details}} -> {:error, details}
      {:error, reason} -> {:error, reason}
    end
  end

  def fetch_chat_members(token, id) do
    api_url = Application.get_env(:text_messenger_client, :api_url)
    endpoint_url = "#{api_url}/chats/#{id}/users"

    with {:ok, body} <- fetch_request(endpoint_url, token) do
      Users.decode(body)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def fetch_users(token) do
    api_url = Application.get_env(:text_messenger_client, :api_url)
    endpoint_url = "#{api_url}/users"

    with {:ok, body} <- fetch_request(endpoint_url, token) do
      Users.decode(body)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def fetch_user(token, id) do
    api_url = Application.get_env(:text_messenger_client, :api_url)
    endpoint_url = "#{api_url}/users/#{id}"

    with {:ok, body} <- fetch_request(endpoint_url, token) do
      User.decode(body)
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
