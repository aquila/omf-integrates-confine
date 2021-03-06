#
# Copyright (c) 2006-2009 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2009 WINLAB, Rutgers University, USA
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
#
module OMF
  module EC; end 
end

require 'omf-expctl/nodeHandler'

startTime = Time.now
@@cleanexit = true

# Initialize the state tracking, Parse the command line options, and run the EC
begin
  puts ""
  TraceState.init()
  NodeHandler.instance.parseOptions(ARGV)
  NodeHandler.instance.run(self)

# Process the various Exceptions...
rescue Interrupt, SystemExit
  # ignore, our Event mechanism now handles this
rescue OEDLException => ex 
  begin
    return if ex.to_s == "(SystemExit) exit"
    @@cleanexit = false
    bt = ex.backtrace 
    MObject.fatal('run', "----------")
    MObject.fatal('run', "  A fatal error was encountered while processing "+
                         "your experiment description.")
    MObject.fatal('run', "  Exception: #{ex.class}")
    MObject.fatal('run', "  Exception: #{ex}")
    MObject.fatal('run', "  In file: #{bt[0]}")
    MObject.fatal('run', "----------")
    MObject.debug('run', "\n\nTrace:\n\t#{bt.join("\n\t")}\n")
  rescue Exception
  end
rescue ServiceException => sex
  begin
    @@cleanexit = false
    MObject.fatal('run', "Failed to call an Aggregate Manager Service")
    MObject.fatal('run', "Exception: #{sex.message} : #{sex.response.body}")
  rescue Exception
  end
rescue Exception => ex
  @@cleanexit = false
  if Experiment.running?
    begin
      MObject.fatal('run', "----------")
      MObject.fatal('run', "  A fatal error was encountered while running your"+
                           " experiment.")
    rescue Exception
    end
  else 
    MObject.fatal('run', "----------")
    MObject.fatal('run', "  Exception raised, no experiment running.")
  end
  MObject.fatal('run', "  Exception (#{ex.class}): #{ex}")
  MObject.fatal('run', "  For more information see the EC log file")
  MObject.fatal('run', "  (usually at: /tmp/#{Experiment.ID}.log)")
  MObject.fatal('run', "  (or see config file to find the log's location)")
  bt = ex.backtrace.join("\n\t")
  MObject.debug('run', "Trace:\n\t#{bt}\n")
  MObject.fatal('run', "----------")
end

# If EC is called in 'interactive' mode, then start a Ruby interpreter
#if NodeHandler.instance.interactive?
#  require 'omf-expctl/console'
#  
#  OMF::EC::Console.instance.run
##  require 'irb'
##  ARGV.clear
##  ARGV << "--simple-prompt"
##  ARGV << "--noinspect"
##  IRB.start()
#end

# End of the experimentation, Shutdown the EC
if (NodeHandler.instance.running?)
  NodeHandler.instance.shutdown
  duration = (Time.now - startTime).to_i
  OMF::EC::OML::PerformanceMonitor.report_status 'EXP.DONE', "Running for #{duration} sec"
  MObject.info('run', "Experiment #{Experiment.ID} finished after #{duration / 60}:#{duration % 60}\n")
end

exit(@@cleanexit)