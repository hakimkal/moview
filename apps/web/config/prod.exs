use Mix.Config

# For production, we often load configuration from external
# sources, such as your system environment. For this reason,
# you won't find the :http configuration below, but set inside
# Moview.WebWeb.Endpoint.init/2 when load_from_system_env is
# true. Any dynamic configuration should be done there.
#
# Don't forget to configure the url host to something meaningful,
# Phoenix uses this information when generating URLs.
#
# Finally, we also include the path to a cache manifest
# containing the digested version of static files. This
# manifest is generated by the mix phx.digest task
# which you typically run after static files are built.
config :web, Moview.Web.Endpoint,
  load_from_system_env: true,
  http: [port: System.get_env("MOVIEW_PORT"), compress: true],
  url: [host: "localhost", port: System.get_env("MOVIEW_PORT")],,
  check_origin: ["//127.0.0.1", "//109.237.25.250", "//localhost", "//moview.com.ng"],
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true,
  version: Application.spec(:web, :vsn)

# Do not print debug messages in production
config :logger,
  level: :info

config :logger,
  backends: [{LoggerFileBackend, :info},
               {LoggerFileBackend, :error}]

config :logger, :info,
  path: "../../logs/web/info.log",
  format: "[$date] [$time] [$level] $metadata $levelpad$message\n",
  metadata: [:date, :application, :module, :function, :line],
  level: :warn

config :logger, :error,
  path: "../../logs/web/error.log",
  format: "[$date] [$time] [$level] $metadata $levelpad$message\n",
  metadata: [:date, :application, :module, :function, :line],
  level: :error

# ## SSL Support
#
# To get SSL working, you will need to add the `https` key
# to the previous section and set your `:url` port to 443:
#
#     config :web, Moview.Web.Endpoint,
#       ...
#       url: [host: "example.com", port: 443],
#       https: [:inet6,
#               port: 443,
#               keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
#               certfile: System.get_env("SOME_APP_SSL_CERT_PATH")]
#
# Where those two env variables return an absolute path to
# the key and cert in disk or a relative path inside priv,
# for example "priv/ssl/server.key".
#
# We also recommend setting `force_ssl`, ensuring no data is
# ever sent via http, always redirecting to https:
#
#     config :web, Moview.Web.Endpoint,
#       force_ssl: [hsts: true]
#
# Check `Plug.SSL` for all available options in `force_ssl`.

# ## Using releases
#
# If you are doing OTP releases, you need to instruct Phoenix
# to start the server for all endpoints:
#
#     config :phoenix, :serve_endpoints, true
#
# Alternatively, you can configure exactly which server to
# start per endpoint:
#
#     config :web, Moview.Web.Endpoint, server: true
#
config :web, Moview.Web.Endpoint,
  secret_key_base: "zWM0eL77sJD/BG/+MshhuwxrDgji4Uro7flFlpbHUN0wK3yTjABxkvHd4oqKXrJ+"
