defmodule Cloudflareq.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/reptarlabs/cloudflareq"

  def project do
    [
      app: :cloudflareq,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  def cli do
    [preferred_envs: [docs: :docs, "hex.publish": :docs, precommit: :test]]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp docs do
    [
      extras: ["livebooks/clients.livemd"],
      groups_for_extras: [
        Guides: ["livebooks/clients.livemd"]
      ],
      groups_for_modules: [
        D1: [Cloudflareq.D1, Cloudflareq.D1.Result, Cloudflareq.Database],
        R2: [Cloudflareq.R2, Cloudflareq.R2.Bucket, Cloudflareq.R2.TempCredentials],
        Workers: [Cloudflareq.Workers, Cloudflareq.Workers.Script],
        Queues: [
          Cloudflareq.Queues,
          Cloudflareq.Queues.Queue,
          Cloudflareq.Queues.Consumer,
          Cloudflareq.Queues.Message,
          Cloudflareq.Queues.AckResult
        ],
        Errors: [Cloudflareq.Error, Cloudflareq.ErrorData, Cloudflareq.TokenError],
        Auth: [Cloudflareq.Token]
      ]
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:req_s3, "~> 0.2", optional: true},
      {:plug, "~> 1.0", only: :test},
      {:ex_doc, ">= 0.0.0", only: :docs, runtime: false}
    ]
  end

  defp aliases do
    [
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end

  defp package do
    [
      description: "Req plugins for Cloudflare APIs.",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end
end
