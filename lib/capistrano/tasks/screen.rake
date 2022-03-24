git_plugin = self

namespace :puma do
  namespace :screen do
    desc 'Start puma through screen'
    task :start do
      on roles(fetch(:puma_role)) do |role|
        git_plugin.puma_switch_user(role) do
          if test "[ -f #{fetch(:puma_pid)} ]" and test :kill, "-0 $( cat #{fetch(:puma_pid)} )"
            info 'Puma is already running'
          else
            within current_path do
              with rack_env: fetch(:puma_env) do
                releases = capture(:ls, "-x", releases_path).split
                releases << release_timestamp.to_s if release_timestamp
                releases.uniq

                latest_release_version = releases.last
                raise "Invalid release timestamp: #{release_timestamp}" unless latest_release_version

                puma_args = [
                  "-C #{fetch(:puma_conf)}",
                  "--control-url tcp://127.0.0.1:9293",
                  "--control-token foobar"
                ]

                command = "/usr/bin/screen -dmS puma#{latest_release_version} bash -c 'cd #{release_path} && #{SSHKit.config.command_map.prefix[:puma].join(" ")} puma #{puma_args.join(" ")}'"
                execute command
              end
            end
          end
        end
      end
    end

    %w[halt stop status].map do |command|
      desc "#{command} puma"
      task command do
        on roles (fetch(:puma_role)) do |role|
          within current_path do
            git_plugin.puma_switch_user(role) do
              with rack_env: fetch(:puma_env) do
                if test "[ -f #{fetch(:puma_pid)} ]"
                  if test :kill, "-0 $( cat #{fetch(:puma_pid)} )"
                    execute :pumactl, "--control-url 'tcp://127.0.0.1:9293'", "--control-token foobar", "-F #{fetch(:puma_conf)} #{command}"
                  else
                    # delete invalid pid file , process is not running.
                    execute :rm, fetch(:puma_pid)
                  end
                else
                  #pid file not found, so puma is probably not running or it using another pidfile
                  warn 'Puma not running'
                end
              end
            end
          end
        end
      end
    end

    %w[phased-restart restart].map do |command|
      desc "#{command} puma"
      task command do
        on roles (fetch(:puma_role)) do |role|
          within current_path do
            git_plugin.puma_switch_user(role) do
              with rack_env: fetch(:puma_env) do
                if test "[ -f #{fetch(:puma_pid)} ]" and test :kill, "-0 $( cat #{fetch(:puma_pid)} )"
                  # NOTE pid exist but state file is nonsense, so ignore that case
                  execute :pumactl, "--control-url 'tcp://127.0.0.1:9293'", "--control-token foobar", "-F #{fetch(:puma_conf)} #{command}"
                else
                  # Puma is not running or state file is not present : Run it
                  invoke 'puma:screen:start'
                end
              end
            end
          end
        end
      end
    end

    task :smart_restart do
      if !fetch(:puma_preload_app) && fetch(:puma_workers, 0).to_i > 1
        invoke 'puma:screen:phased-restart'
      else
        invoke 'puma:screen:restart'
      end
    end
  end
end
