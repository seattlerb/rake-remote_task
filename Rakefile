# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.plugin :seattlerb
Hoe.plugin :isolate

Hoe.spec 'rake-remote_task' do
  developer 'Ryan Davis',       'ryand-ruby@zenspider.com'
  developer 'Eric Hodel',       'drbrain@segment7.net'
  developer 'Wilson Bilkovich', 'wilson@supremetyrant.com'

  self.rubyforge_name = 'hitsquad'

  dependency 'rake',     '~> 0.8'
  dependency 'open4',    '~> 1.0' unless RUBY_PLATFORM =~ /java/

  multiruby_skip << "rubinius"

  if RUBY_PLATFORM =~ /java/
    spec_extras[ :platform ] = Gem::Platform.new( "java" )
  end
end

# vim: syntax=ruby
