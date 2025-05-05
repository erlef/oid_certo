defmodule OIDCerto.MixProject do
  use Mix.Project

  def project do
    [
      app: :oid_certo,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases(),
      dialyzer: [plt_add_apps: [:mix]]
    ]
  end

  def application do
    [
      extra_applications: [:ex_unit, :logger, :ssh],
      mod: {OIDCerto.Application, []}
    ]
  end

  def releases do
    [
      oid_certo: [
        steps: [:assemble, &Burrito.wrap/1],
        burrito: [
          targets: [
            Linux_X64: [os: :linux, cpu: :x86_64]
            # TODO: Re-enable
            # Linux_ARM64: [os: :linux, cpu: :aarch64],
            # macOS_X64: [os: :darwin, cpu: :x86_64],
            # macOS_ARM64: [os: :darwin, cpu: :aarch64],
            # Windows_X64: [os: :windows, cpu: :x86_64]
            # Not currently supported by Burrito
            # Windows_ARM64: [os: :windows, cpu: :aarch64]
          ]
        ]
      ]
    ]
  end

  defp deps do
    # styler:sort
    [
      {:bandit, "~> 1.0"},
      {:burrito, "~> 1.3"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:erlexec, "~> 2.2"},
      {:localhost_run, "~> 0.1.0"},
      {:mime, "~> 2.0"},
      {:optimus, "~> 0.5.1"},
      {:plug, "~> 1.17"},
      {:req, "~> 0.5.10"},
      {:reverse_proxy_plug, "~> 3.0"},
      {:styler, "~> 1.4", only: [:dev, :test], runtime: false},
      {:wallaby, "~> 0.30.10"}
    ]
  end
end
