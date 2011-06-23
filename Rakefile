# -*- ruby -*-

require 'rubygems'
require 'hoe'

# Hoe.plugin :isolate - isolates during rake release and borks manifest check
Hoe.plugin :seattlerb

Hoe.spec 'rake-remote_task' do
  developer 'Ryan Davis',       'ryand-ruby@zenspider.com'
  developer 'Eric Hodel',       'drbrain@segment7.net'
  developer 'Wilson Bilkovich', 'wilson@supremetyrant.com'

  self.rubyforge_name = 'hitsquad'

  dependency 'rake',     '~> 0.8'
  dependency 'open4',    '~> 0.9.0'

  multiruby_skip << "rubinius"
end

# vim: syntax=ruby
