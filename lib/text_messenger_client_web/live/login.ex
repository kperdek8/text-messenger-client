defmodule TextMessengerClientWeb.LoginPage do
  use TextMessengerClientWeb, :live_view

  import TextMessengerClient.UsersAPI

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:is_registering, false)
      |> assign(:message, "")
    {:ok, socket} 
  end

  def render(assigns) do
    ~H"""
    <div id="auth-container" class="flex items-center justify-center w-screen h-screen bg-gradient-to-br from-gray-800 to-gray-900">
      <div class="w-full max-w-md p-8 bg-gray-800 text-gray-200 rounded-lg shadow-lg">

        <!-- Form Title -->
        <h2 class="text-2xl font-bold text-center">
          <%= if @is_registering, do: "Register", else: "Login" %>
        </h2>

        <!-- Message Display -->
        <div :if={@message != ""} class="text-center mt-2 text-red-500">
          <%= @message %>
        </div>

        <!-- Login/Registration Form -->
        <form phx-submit={if @is_registering, do: "register", else: "login"} class="flex flex-col gap-4 mt-4">

          <!-- Username Field -->
          <input
            name="username"
            type="text"
            placeholder="Username"
            class="w-full p-2 bg-gray-700 border border-gray-600 rounded-lg focus:outline-none text-gray-200"
            required
          />

          <!-- Password Field -->
          <input
            name="password"
            type="password"
            placeholder="Password"
            class="w-full p-2 bg-gray-700 border border-gray-600 rounded-lg focus:outline-none text-gray-200"
            required
          />

          <!-- Password Confirmation Field (visible for registration) -->
          <input
            :if={@is_registering}
            name="password_confirmation"
            type="password"
            placeholder="Confirm Password"
            class="w-full p-2 bg-gray-700 border border-gray-600 rounded-lg focus:outline-none text-gray-200"
            required
          />

          <!-- Submit Button -->
          <button
            type="submit"
            class="w-full p-2 bg-blue-500 hover:bg-blue-600 text-white font-bold rounded-lg mt-4">
            <%= if @is_registering, do: "Register", else: "Login" %>
          </button>
        </form>

        <!-- Toggle between Login and Registration -->
        <div class="text-center mt-4">
          <a href="#" phx-click="toggle-auth" class="text-blue-400 hover:underline">
            <%= if @is_registering, do: "Already have an account? Login", else: "Don't have an account? Register" %>
          </a>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("toggle-auth", _params, socket) do
    {:noreply, assign(socket, is_registering: !socket.assigns.is_registering)}
  end

  def handle_event("login", %{"username" => username, "password" => password}, socket) do
    with {:ok, {token, _username, _user_id}} <- login(username, password) do
      socket =
        socket
        |> assign(token: token)
        |> redirect(to: "/")
      {:noreply, socket}
    else
      {:error, %{"error" => error}} -> {:noreply, assign(socket, message: error)}
    end
  end

  def handle_event("register", %{"username" => username, "password" => password, "password_confirmation" => password_confirmation}, socket) do
    if password == password_confirmation do
      with {:ok, message}<- TextMessengerClient.UsersAPI.register(username, password) do
        {:noreply, assign(socket, :message, message)}
      else
        {:error, details} -> {:noreply, assign(socket, message: format_error(details))}
      end
    else
      {:noreply, assign(socket, :message, "Passwords do not match.")}
    end
  end

  defp format_error(details) do
    [{key, [message | _rest]}] = Enum.take(details, 1) # Get the first key-value pair
    "#{key} #{message}"
  end
end
