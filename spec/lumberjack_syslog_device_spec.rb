require 'spec_helper'

describe Lumberjack::SyslogDevice do
  
  let(:time){ Time.parse("2011-02-01T18:32:31Z") }
  let(:entry){ Lumberjack::LogEntry.new(time, Lumberjack::Severity::WARN, "message 1", "lumberjack_syslog_device_spec", 12345, "ABCD") }

  after( :each ) do
    Syslog.close if Syslog.opened?
  end

  context "open connecton" do  
    let!( :syslog ) { MockSyslog.new }

    it "should be able to specify syslog options" do
      Syslog.should_receive(:open).with(entry.progname, Syslog::LOG_CONS, nil)
      Syslog.should_receive( :mask= ).with( Syslog.LOG_UPTO( Syslog::LOG_DEBUG ) )
      Lumberjack::SyslogDevice.new(:ident => entry.progname, :options => Syslog::LOG_CONS)
    end
  
    it "should be able to specify a syslog facility" do
      Syslog.should_receive(:open).with(entry.progname, (Syslog::LOG_PID | Syslog::LOG_CONS), Syslog::LOG_FTP)
      Syslog.should_receive( :mask= ).with( Syslog.LOG_UPTO( Syslog::LOG_DEBUG ) )
      Lumberjack::SyslogDevice.new(:ident => entry.progname, :facility => Syslog::LOG_FTP)
    end
  
    it "should log all messages since the logger will filter them by severity" do
      Syslog.should_receive(:open).with(nil, (Syslog::LOG_PID | Syslog::LOG_CONS), nil)
      Syslog.should_receive( :mask= ).with( Syslog.LOG_UPTO( Syslog::LOG_DEBUG ) )
      Lumberjack::SyslogDevice.new
    end
  end
  
  context "logging" do
    it "should log entries to syslog" do
      entry.unit_of_work_id = nil
      messages = read_syslog do
        device = Lumberjack::SyslogDevice.new( :ident => "lumberjack_syslog_device_spec" )
        device.write(entry)
      end
      messages.first.should include("message 1")
    end
  
    it "should log output to syslog with the unit of work id if it exists" do
      messages = read_syslog do
        device = Lumberjack::SyslogDevice.new( :ident => "lumberjack_syslog_device_spec" )
        device.write(entry)
      end
      messages.first.should include("message 1 (#ABCD)")
    end
  
    it "should be able to specify a string template" do
      messages = read_syslog do
        device = Lumberjack::SyslogDevice.new(:template => ":unit_of_work_id - :message",
                                              :ident => "lumberjack_syslog_device_spec" )
        device.write(entry)
      end
      messages.first.should include("ABCD - message 1")
    end
  
    it "should be able to specify a proc template" do
      messages = read_syslog do
        device = Lumberjack::SyslogDevice.new(:template => lambda{|e| e.message.upcase},
                                              :ident => "lumberjack_syslog_device_spec" )
        device.write(entry)
      end
      messages.first.should include("MESSAGE 1")
    end
  
    it "should properly handle percent signs in the syslog message" do
      entry.message = "message 100%"
      messages = read_syslog do
        device = Lumberjack::SyslogDevice.new( :ident => "lumberjack_syslog_device_spec" )
        device.write(entry)
      end
      messages.first.should include("message 100% (#ABCD)")
    end
  
    it "should convert lumberjack severities to syslog severities" do
      device = Lumberjack::SyslogDevice.new
      Syslog.should_receive(:log).with(Syslog::LOG_DEBUG, "debug")
      Syslog.should_receive(:log).with(Syslog::LOG_INFO, "info")
      Syslog.should_receive(:log).with(Syslog::LOG_WARNING, "warn")
      Syslog.should_receive(:log).with(Syslog::LOG_ERR, "error")
      Syslog.should_receive(:log).with(Syslog::LOG_CRIT, "fatal")
      device.write(Lumberjack::LogEntry.new(Time.now, Lumberjack::Severity::DEBUG, "debug", "lumberjack_syslog_device_spec", 12345, nil))
      device.write(Lumberjack::LogEntry.new(Time.now, Lumberjack::Severity::INFO, "info", "lumberjack_syslog_device_spec", 12345, nil))
      device.write(Lumberjack::LogEntry.new(Time.now, Lumberjack::Severity::WARN, "warn", "lumberjack_syslog_device_spec", 12345, nil))
      device.write(Lumberjack::LogEntry.new(Time.now, Lumberjack::Severity::ERROR, "error", "lumberjack_syslog_device_spec", 12345, nil))
      device.write(Lumberjack::LogEntry.new(Time.now, Lumberjack::Severity::FATAL, "fatal", "lumberjack_syslog_device_spec", 12345, nil))
    end
  end
end
