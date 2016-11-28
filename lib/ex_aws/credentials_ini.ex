if Code.ensure_loaded?(ConfigParser) do
  defmodule ExAws.CredentialsIni do
    def security_credentials(profile_name) do
      shared_credentials = profile_from_shared_credentials(profile_name)
      config_credentials = profile_from_config(profile_name)
      Map.merge(config_credentials, shared_credentials)
    end

    def parse_ini_file({:ok, contents}, profile_name) do
      parsed_contents = contents
      |> ConfigParser.parse_string

      case parsed_contents do
        {:ok, %{^profile_name => config}} ->
	  config
          |> strip_key_prefix
	{:ok, %{}} -> raise "Missing #{profile_name} entry in configuration"
        _ -> %{}
      end
    end
    def parse_ini_file(_, _), do: %{}

    def strip_key_prefix(credentials) do
      credentials
      |> Enum.filter(fn({key, val}) -> Enum.member?(~w(aws_access_key_id aws_secret_access_key aws_session_token region), key) end)
      |> Enum.reduce(%{}, fn({key, val}, acc) ->
        updated_key = key
        |> String.replace_leading("aws_", "")
        |> String.to_atom
        Map.put(acc, updated_key, val)
      end)
    end

    def replace_token_key(credentials) do
      case Map.pop(credentials, :session_token) do
	{nil, credentials} ->
	  credentials
	{token, credentials} ->
	  Map.put(credentials, :security_token, token)
      end
    end

    defp profile_from_shared_credentials(profile_name) do
      File.read("#{System.user_home}/.aws/credentials")
      |> parse_ini_file(profile_name)
      |> replace_token_key
    end

    defp profile_from_config(profile_name) do
      section = case profile_name do
		  "default" -> "default"
		  other -> "profile #{other}"
		end
      File.read("#{System.user_home}/.aws/config")
      |> parse_ini_file(section)
    end

  end
else
  defmodule ExAws.CredentialsIni do
    def security_credentials(_), do: raise "ConfigParser required to use"
    def parse_ini_file(_, _), do: raise "ConfigParser required to use"
    def replace_token_key(_), do: raise "ConfigParser required to use"
  end
end
