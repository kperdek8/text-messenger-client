defmodule TextMessengerClient.RequestHandler do
  require Logger

  def fetch_request(endpoint, token \\ nil) do
    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/x-protobuf"}
    ]

    headers = if token, do: [{"Authorization", "Bearer #{token}"} | headers], else: headers

    Logger.debug("Sending GET request #{endpoint}}")

    case HTTPoison.get(endpoint, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: 401, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"error" => _error, "reason" => reason}} ->
            {:error, reason}

          {:ok, %{"error" => error}} ->
            {:error, "Unauthorized: #{error}"}

          {:error, _reason} ->
            {:error, "Failed to decode error response"}
        end

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Error: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP error: #{reason}"}
    end
  end

  def post_request(endpoint, payload, token \\ nil) do
    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json, application/x-protobuf"}
    ]

    headers = if token, do: [{"Authorization", "Bearer #{token}"} | headers], else: headers

    Logger.debug("Sending POST request #{endpoint}}")

    case HTTPoison.post(endpoint, payload, headers) do
      {:ok, %HTTPoison.Response{status_code: status_code, body: body, headers: response_headers}} ->
        content_type = get_content_type(response_headers)

        case content_type do
          "application/json" ->
            {:ok, status_code, Jason.decode!(body)}

          "application/x-protobuf" ->
            {:ok, status_code, body} # Leave protobuf decoding to calling function

        _ ->
          {:error, "Unsupported content type: #{content_type}"}
      end

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP error: #{reason}"}
    end
  end


  defp get_content_type(headers) do
    headers
    |> Enum.find(fn {key, _} -> key == "content-type" end)
    |> case do
         nil -> nil
         {"content-type", type}  -> String.split(type, ";") |> List.first()
       end
  end
end
