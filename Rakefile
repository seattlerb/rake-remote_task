# -*- ruby -*-

require 'hoe'

Hoe.plugin :seattlerb
Hoe.plugin :isolate

Hoe.spec 'rake-remote_task' do
  developer 'Ryan Davis',       'ryand-ruby@zenspider.com'
  developer 'Eric Hodel',       'drbrain@segment7.net'
  developer 'Wilson Bilkovich', 'wilson@supremetyrant.com'

  dependency 'rake',    ['>= 0.8', '< 15.0']
  dependency 'open4',    '~> 1.0'

  license "MIT"

  multiruby_skip << "rubinius"
end

# vim: syntax=ruby
