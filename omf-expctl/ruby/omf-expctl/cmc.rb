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
# = cmc.rb
#
# == Description
#
# This module holds the methods used by the EC to interact with
# the CMC Services
#

module CMC

  # Holds the list of active nodes for this experiment
  @@activeNodes = nil

  #
  # Switch a given node ON
  #
  def CMC.nodeOn(name)
    if NodeHandler.JUST_PRINT
      puts ">> CMC: Switch on node '#{name}'"
    else
      begin
puts ">>>>> CMC: nodeOn '#{name}' - 1"
        OMF::Services.cmc.on(name)
puts ">>>>> CMC: nodeOn '#{name}' - 2"
      rescue Exception => ex
        MObject.debug("CMC", "Can't switch ON node '#{name}'")
      end
    end
  end

  #
  # Switch a given set of nodes ON
  #
  # - set = a String describing the set of nodes to switch ON
  #
  def CMC.nodeSetOn(set)
    if NodeHandler.JUST_PRINT
      puts ">> CMC: Switch on nodes #{set}"
    else
      begin
        OMF::Services.cmc.nodeseton(set)
      rescue Exception => ex
        MObject.debug("CMC", "Can't switch ON nodes '#{set}'")
      end
    end
  end

  #
  # Switch a given node OFF Hard
  # (i.e. similar to a push of 'power' button)
  #
  def CMC.nodeOffHard(name)
    if NodeHandler.JUST_PRINT
      puts "CMC: Switch of node #{name}"
    else
      begin
        OMF::Services.cmc.offhard(name)
      rescue Exception => ex
        MObject.debug("CMC", "Can't switch OFF node '#{name}'")
      end
    end
  end

  #
  # Switch a given node OFF Soft
  # (i.e. similar to a console call to 'halt -p' on the node)
  #
  def CMC.nodeOffSoft(name)
    if NodeHandler.JUST_PRINT
      puts "CMC: Switch of node #{name}"
    else
      begin
        OMF::Services.cmc.offsoft(name)
      rescue Exception => ex
        MObject.debug("CMC", "Can't switch OFF node '#{name}'")
      end
    end
  end

  #
  # Switch all nodes OFF Hard
  # (i.e. similar to a push of 'power' button)
  #
  def CMC.nodeAllOffHard()
    if NodeHandler.JUST_PRINT
      puts "CMC: Switch off hard node"
    else
      begin
        OMF::Services.cmc.alloffhard
      rescue Exception => ex
        MObject.debug("CMC", "Can't switch OFF all nodes")
      end
    end
  end

  #
  # Switch all nodes OFF Soft
  # (i.e. similar to a console call to 'halt -p' on the node)
  #
  def CMC.nodeAllOffSoft()
    if NodeHandler.JUST_PRINT
      puts "CMC: Switch off soft node"
    else
      begin
        OMF::Services.cmc.alloffsoft
      rescue Exception => ex
        MObject.debug("CMC", "Can't switch OFF all nodes")
      end
    end
  end

  #
  # Reset a particular node
  #
  def CMC.nodeReset(name)
    if NodeHandler.JUST_PRINT
      puts "CMC: Reset node #{name}"
    else
      begin
        OMF::Services.cmc.reset(name)
      rescue Exception => ex
        MObject.debug("CMC", "Can't reset node '#{name}'")
      end
    end
  end
end
