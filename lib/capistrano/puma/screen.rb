module Capistrano
  class Puma::Screen < Capistrano::Plugin
    include PumaCommon

    def register_hooks
      after 'deploy:finished', 'puma:screen_smart_restart'
    end

    def define_tasks
      eval_rakefile File.expand_path('../../tasks/screen.rake', __FILE__)
    end
  end
end
