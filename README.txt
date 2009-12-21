= rake-remote_task

* http://rubyhitsquad.com/
* http://rubyforge.org/projects/hitsquad/

== DESCRIPTION:

Vlad the Deployer's sexy brainchild is rake-remote_task, extending
Rake with remote task goodness.

== FEATURES/PROBLEMS:

* Run remote commands on one or more servers.
* Mix and match local and remote tasks.
* Uses ssh with your ssh settings already in place.
* Uses rsync for efficient transfers.

== SYNOPSIS:

  remote_task :setup_app, :roles => :app do
    # ...
    run "umask #{umask} && mkdir -p #{dirs.join(' ')}"
  end

== REQUIREMENTS:

* rake, >= 0.8

== INSTALL:

* sudo gem install rake-remote_task

== LICENSE:

(The MIT License)

Copyright (c) Ryan Davis, RubyHitSquad

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
