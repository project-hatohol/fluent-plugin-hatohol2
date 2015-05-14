# Copyright (C) 2014 Project Hatohol
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

class BuildMessageTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  def parse_config(config)
    use_v1 = true
    config_string = <<-CONFIG
      type hatohol
      queue_name gate.1
    CONFIG
    config.each do |key, value|
      config_string << "#{key} #{value}\n"
    end
    Fluent::Config.parse(config_string, "(test)", "(test_dir)", use_v1)
  end

  def create_plugin(config)
    plugin = Fluent::HatoholOutput.new
    plugin.configure(parse_config(config))
    plugin
  end

  def call_build_events(config, tag, time, record)
    create_plugin(config).send(:build_events, tag, time, record)
  end

  sub_test_case("time") do
    def build_time(config, time, record)
      record["message"] = "Message"
      message = call_build_events(config,
                                  "hatohol.syslog.messages",
                                  time,
                                  record)
      message["params"]["events"][0]["time"]
    end

    def test_time
      time = Time.utc(2015, 5, 14, 12, 50, 8)
      assert_equal("20150514125008", build_time({}, time, {}))
    end
  end

  sub_test_case("type") do
    def build_type(config, record)
      record["message"] = "Message"
      message = call_build_events(config,
                                  "hatohol.syslog.messages",
                                  Fluent::Engine.now,
                                  record)
      message["params"]["events"][0]["type"]
    end

    def test_default
      assert_equal("BAD", build_type({}, {}))
    end
  end

  sub_test_case("host") do
    def build_host(config, record)
      record["message"] = "Message"
      message = call_build_events(config,
                                   "hatohol.syslog.messages",
                                   Fluent::Engine.now,
                                   record)
      message["params"]["events"][0]["hostName"]
    end

    def test_default
      assert_equal("www.example.com",
                   build_host({}, {"host" => "www.example.com"}))
    end

    def test_custom
      assert_equal("www.example.com",
                   build_host({
                                "host_key" => "hostname",
                              },
                              {"hostname" => "www.example.com"}))
    end
  end

  sub_test_case("brief") do
    def build_content(config, record)
      record["host"] ||= "www.example.com"
      message = call_build_events(config,
                                   "hatohol.syslog.messages",
                                   Fluent::Engine.now,
                                   record)
      message["params"]["events"][0]["brief"]
    end

    def test_default
      assert_equal("Message",
                   build_content({}, {"message"=> "Message"}))
    end

    def test_multiple
      assert_equal("Message at www.example.com",
                   build_content({
                                   "content_format" => "%{message} at %{host}",
                                 },
                                 {
                                   "host" => "www.example.com",
                                   "message" => "Message",
                                 }))
    end
  end

  sub_test_case("severity") do
    def build_severity(config, record)
      record["host"] ||= "www.example.com"
      record["message"] ||= "Error!"
      message = call_build_events(config,
                                   "hatohol.syslog.messages",
                                   Fluent::Engine.now,
                                   record)
      message["params"]["events"][0]["severity"]
    end

    def test_default
      assert_equal("ERROR",
                   build_severity({}, {}))
    end

    def test_constatnt
      assert_equal("warning",
                   build_severity({"severity_format" => "warning"},
                                  {}))
    end

    def test_parameter
      assert_equal("critical",
                   build_severity({"severity_format" => "%{severity}"},
                                  {"severity" => "critical"}))
    end
  end
end
