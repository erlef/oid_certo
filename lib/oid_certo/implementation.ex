defmodule OIDCerto.Implementation do
  @moduledoc false

  require Logger

  defstruct [:pid, :os_pid, :stdin_fd, :stdout_fd, :stderr_fd]

  def start(out_dir) do
    executable = Application.fetch_env!(:oid_certo, __MODULE__)[:executable]

    report_pid = self()

    with {:ok, stdin_fd} <- File.open(Path.join(out_dir, "implementation.stdin.log"), [:append]),
         {:ok, stdout_fd} <- File.open(Path.join(out_dir, "implementation.stdout.log"), [:append]),
         {:ok, stderr_fd} <- File.open(Path.join(out_dir, "implementation.stderr.log"), [:append]),
         {:ok, pid, os_pid} <-
           executable
           |> String.to_charlist()
           |> :exec.run([
             :monitor,
             :stdin,
             stdout: handle_out(report_pid, stdout_fd),
             stderr: handle_out(report_pid, stderr_fd)
           ]) do
      {:ok, %__MODULE__{pid: pid, os_pid: os_pid, stdin_fd: stdin_fd, stdout_fd: stdout_fd, stderr_fd: stderr_fd}}
    end
  end

  def command(%__MODULE__{pid: pid, os_pid: os_pid, stdin_fd: stdin_fd}, command) do
    out = IO.iodata_to_binary(["CMD ", JSON.encode!(command), "\n"])

    :ok = :exec.send(pid, out)
    IO.write(stdin_fd, out)
    Logger.info("#{out}", os_pid: os_pid, device: :stdin)

    receive do
      {^os_pid, {:ack, nil}} -> :ok
      {^os_pid, {:ack, info}} -> {:ok, info}
      {^os_pid, {:nack, nil}} -> {:error, :nack}
      {^os_pid, {:nack, info}} -> {:error, info}
      {:DOWN, ^os_pid, :process, ^pid, _reason} -> {:error, :stopped}
    after
      10_000 -> {:error, :timeout}
    end
  end

  def shutdown(%__MODULE__{pid: pid, os_pid: os_pid} = impl) do
    if Process.alive?(pid) do
      :exec.send(pid, :eof)

      receive do
        {:DOWN, ^os_pid, :process, ^pid, :normal} -> :ok
        {:DOWN, ^os_pid, :process, ^pid, reason} -> {:error, reason}
      after
        10_000 -> :exec.stop(pid)
      end
    else
      :ok
    end
  after
    File.close(impl.stdin_fd)
    File.close(impl.stdout_fd)
    File.close(impl.stderr_fd)
  end

  def handle_out(pid, out_fd) do
    fn
      :stdout, os_pid, "ACK" <> rest = message ->
        IO.write(out_fd, message)

        Logger.info("#{message}", os_pid: os_pid, device: :stdout)

        case String.trim(rest) do
          "" -> send(pid, {os_pid, {:ack, nil}})
          info -> send(pid, {os_pid, {:ack, JSON.decode!(info)}})
        end

      :stdout, os_pid, "NACK" <> rest = message ->
        IO.write(out_fd, message)

        Logger.info("#{message}", os_pid: os_pid, device: :stdout)

        case String.trim(rest) do
          "" -> send(pid, {os_pid, {:nack, nil}})
          info -> send(pid, {os_pid, {:nack, JSON.decode!(info)}})
        end

      :stdout, os_pid, message ->
        IO.write(out_fd, message)

        Logger.error("Unexpected message: #{message}", os_pid: os_pid, device: :stdout)

      :stderr, os_pid, message ->
        IO.write(out_fd, message)

        Logger.info("#{message}", os_pid: os_pid, device: :stderr)

        send(pid, {os_pid, message})
    end
  end
end
