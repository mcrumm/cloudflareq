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
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  def cli do
    [preferred_envs: [docs: :docs, "hex.publish": :docs]]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp docs do
    [
      groups_for_modules: [
        Clients: [Cloudflareq.D1, Cloudflareq.R2],
        Structures: [Cloudflareq.D1.Result, Cloudflareq.Database, Cloudflareq.R2.Bucket, Cloudflareq.R2.TempCredentials],
        Errors: [Cloudflareq.Error]
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

  defp package do
    [
      description: "Req plugins for Cloudflare APIs.",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end
end
