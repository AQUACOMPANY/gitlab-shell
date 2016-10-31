require 'open3'
require 'pathname'
class GitlabCustomHook
  attr_reader :vars

  def initialize(key_id)
    @vars = { 'GL_ID' => key_id }
  end

  def pre_receive(changes, repo_path)
    hook = hook_file('pre-receive')
    return true if hook.nil?

    call_receive_hook(hook, changes, repo_path)
  end

  def post_receive(changes, repo_path)
    hook = hook_file('post-receive')
    return true if hook.nil?

    call_receive_hook(hook, changes, repo_path)
  end

  def update(ref_name, old_value, new_value, repo_path)
    hook = hook_file('update')
    return true if hook.nil?

    system(vars, hook, ref_name, old_value, new_value)
  end

  private

  def call_receive_hook(hook, changes, repo_path)
    # Prepare the hook subprocess. Attach a pipe to its stdin, and merge
    # both its stdout and stderr into our own stdout.
    stdin_reader, stdin_writer = IO.pipe
	vars['REPO_PATH'] = repo_path
    hook_pid = spawn(vars, hook, in: stdin_reader, err: :out)
    stdin_reader.close

    # Submit changes to the hook via its stdin.
    begin
      IO.copy_stream(StringIO.new(changes), stdin_writer)
    rescue Errno::EPIPE
      # It is not an error if the hook does not consume all of its input.
    end

    # Close the pipe to let the hook know there is no further input.
    stdin_writer.close

    Process.wait(hook_pid)
    $?.success?
  end

  def hook_file(hook_type)
#   hook_path = File.join(repo_path.strip, 'custom_hooks')
    hook_path = File.expand_path('../custom_hooks', Pathname.new(File.dirname(__FILE__)).realpath)
    hook_file = "#{hook_path }/#{hook_type}"
    hook_file if File.exist?(hook_file)
  end
end
