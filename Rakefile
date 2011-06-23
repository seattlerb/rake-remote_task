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

  dependency 'rake',     '~> 0.8'
  dependency 'open4',    '~> 0.9.0'
  dependency 'minitest', '~> 1.7.0', :development

  multiruby_skip << "rubinius"
end

# vim: syntax=ruby
