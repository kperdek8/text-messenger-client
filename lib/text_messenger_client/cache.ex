defmodule TextMessengerClient.Cache do
  use GenServer

  alias TextMessengerClient.UsersAPI
  alias TextMessengerClient.KeysAPI
  alias TextMessengerClient.Protobuf.User
  alias TextMessengerClient.Protobuf.UserKeys

  @username_cache_table :username_cache
  @public_key_cache_table :public_key_cache

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    :ets.new(@username_cache_table, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(@public_key_cache_table, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{}}
  end

  # Public API

  def put_username(user_id, username) do
    GenServer.cast(__MODULE__, {:put_username, user_id, username})
  end

  def put_public_keys(user_id, encryption_key, signature_key) do
    GenServer.cast(__MODULE__, {:put_public_keys, user_id, encryption_key, signature_key})
  end

  def get_username(user_id, token) do
    GenServer.call(__MODULE__, {:get_username, user_id, token})
  end

  def get_public_keys(user_id, token) do
    GenServer.call(__MODULE__, {:get_public_keys, user_id, token})
  end

  # GenServer callbacks

  def handle_cast({:put_username, user_id, username}, state) do
    :ets.insert(@username_cache_table, {user_id, username})
    {:noreply, state}
  end

  def handle_cast({:put_public_keys, user_id, encryption_key, signature_key}, state) do
    :ets.insert(@public_key_cache_table, {user_id, {encryption_key, signature_key}})
    {:noreply, state}
  end

  def handle_call({:get_username, user_id, token}, _from, state) do
    case :ets.lookup(@username_cache_table, user_id) do
      [{_user_id, username}] ->
        {:reply, {:ok, username}, state}

      [] ->
        case UsersAPI.fetch_user(token, user_id) do
          %User{name: username} ->
            put_username(user_id, username)
            {:reply, {:ok, username}, state}

          {:error, _reason} ->
            {:reply, {:ok, "Unknown user"}, state}
        end
    end
  end

  def handle_call({:get_public_keys, user_id, token}, _from, state) do
    case :ets.lookup(@public_key_cache_table, user_id) do
      [{_user_id, {encryption_key, signature_key}}] ->
        {:reply, {:ok, {encryption_key, signature_key}}, state}

      [] ->
        case KeysAPI.fetch_user_keys(token, user_id) do
          %UserKeys{encryption_key: encryption_key, signature_key: signature_key} ->
            put_public_keys(user_id, encryption_key, signature_key)
            {:reply, {:ok, {encryption_key, signature_key}}, state}

          {:error, _reason} ->
            {:reply, {:error, :not_found}, state}
        end
    end
  end
end