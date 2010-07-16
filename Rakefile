# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.plugin :isolate
Hoe.plugin :seattlerb

Hoe.spec 'rake-remote_task' do
  developer 'Ryan Davis',       'ryand-ruby@zenspider.com'
  developer 'Eric Hodel',       'drbrain@segment7.net'
  developer 'Wilson Bilkovich', 'wilson@supremetyrant.com'

  self.rubyforge_name = 'hitsquad'

  extra_deps << ['rake',  '~> 0.8.0']
  extra_deps << ['open4', '~> 0.9.0']

  extra_dev_deps << ['minitest', '~> 1.7.0']

  # TODO: remove 1.9
  multiruby_skip << "1.9" << "rubinius"
end

# vim: syntax=ruby
