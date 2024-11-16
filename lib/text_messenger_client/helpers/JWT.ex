defmodule TextMessengerClient.Helpers.JWT do
  def decode_payload(token) do
    case String.split(token, ".") do
      [_header, payload, _signature] ->
        case Base.url_decode64(payload, padding: false) do
          {:ok, json} ->
            case Jason.decode(json) do
              {:ok, claims} when is_map(claims) -> {:ok, claims}
              {:ok, _} -> {:error, "Decoded payload is not a valid map"}
              {:error, reason} -> {:error, "Failed to parse payload JSON: #{reason}"}
            end

          {:error, _reason} ->
            {:error, "Failed to decode payload from base64"}
        end
      _ ->
        {:error, "Invalid JWT format"}
    end
  end
end