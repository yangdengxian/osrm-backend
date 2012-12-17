require 'socket'
require 'open3'

LAUNCH_TIMEOUT = 2
SHUTDOWN_TIMEOUT = 2

class OSRMLauncher
  def initialize &block
    Dir.chdir TEST_FOLDER do
      begin
        launch
        yield
      ensure
        shutdown
      end
    end
  end

  private
  
  def launch
    Timeout.timeout(LAUNCH_TIMEOUT) do
      osrm_up
      wait_for_connection
    end
  rescue Timeout::Error
    log_path = 'osrm-routed.log'
    log_lines = 3
    tail = log_tail log_path,log_lines
    raise OSRMError.new 'osrm-routed', nil, "*** Launching osrm-routed timed out. Last #{log_lines} lines from #{log_path}:\n#{tail}\n" 
  end
  
  def shutdown
    Timeout.timeout(SHUTDOWN_TIMEOUT) do
      osrm_down
    end
  rescue Timeout::Error
    kill
    log_path = 'osrm-routed.log'
    log_lines = 3
    tail = log_tail log_path,log_lines
    raise OSRMError.new 'osrm-routed', nil, "*** Shutting down osrm-routed timed out. Last #{log_lines} lines from #{log_path}:\n#{tail}\n" 
  end
  
  
  def osrm_up?
    if @pid
      `ps -o state -p #{@pid}`.split[1].to_s =~ /^[DRST]/
    else
      false
    end
  end

  def osrm_up
    return if osrm_up?
    @pid = Process.spawn(['../osrm-routed',''],:out=>'osrm-routed.log', :err=>'osrm-routed.log')
  end

  def osrm_down
    if @pid
      Process.kill 'TERM', @pid
      wait_for_shutdown
    end
  end

  def kill
    if @pid
      Process.kill 'KILL', @pid
    end
  end

  def wait_for_connection
    while true
      begin
        socket = TCPSocket.new('localhost', OSRM_PORT)
        return
      rescue Errno::ECONNREFUSED
        sleep 0.1
      end
    end
  end

  def wait_for_shutdown
    while osrm_up?
      sleep 0.1
    end
  end
end
