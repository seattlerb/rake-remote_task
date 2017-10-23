# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.plugin :seattlerb
Hoe.plugin :isolate

Hoe.spec 'rake-remote_task' do
  developer 'Ryan Davis',       'ryand-ruby@zenspider.com'
  developer 'Eric Hodel',       'drbrain@segment7.net'
  developer 'Wilson Bilkovich', 'wilson@supremetyrant.com'

  dependency 'rake',    ['>= 0.8', '< 13.0']
  dependency 'open4',    '~> 1.0'

  multiruby_skip << "rubinius"
end

# vim: syntax=ruby
