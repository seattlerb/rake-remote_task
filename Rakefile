# -*- ruby -*-

require 'rubygems'
require 'hoe'

# HACK Hoe.plugin :isolate # fudging releases - work it out w/ release script
Hoe.plugin :seattlerb

Hoe.spec 'rake-remote_task' do
  developer 'Ryan Davis',       'ryand-ruby@zenspider.com'
  developer 'Eric Hodel',       'drbrain@segment7.net'
  developer 'Wilson Bilkovich', 'wilson@supremetyrant.com'

  self.rubyforge_name = 'hitsquad'

  extra_deps << ['rake',  '>= 0.8.0', '< 0.10.0']
  extra_deps << ['open4', '~> 0.9.0']

  extra_dev_deps << ['minitest', '~> 1.7.0']

  multiruby_skip << "rubinius"
end

# vim: syntax=ruby
