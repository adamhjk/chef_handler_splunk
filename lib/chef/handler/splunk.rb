#
# Copyright 2011, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/handler'

class Chef
  class Handler
    class Splunk < Chef::Handler
      attr_reader :config

      # Creates a new Chef::Handler::Splunk object.
      #
      # @param [Hash] configuration parameters:
      #   :path => the path for the splunk data - defaults to /var/chef/splunk
      #   :keep => the number of backup data files to keep - defaults to 10
      def initialize(config={})
        @config = config
        @config[:path] ||= "/var/chef/splunk"
        @config[:keep] ||= 10 
        @config
      end

      # The body of the handler - creates run reports for Splunk. Results in
      # three different files being created:
      #
      #   node.data - A k=v flattened list of node attributes, akin to search
      #   run.data - Information about the last chef run 
      #   resource.data - Information about every chef resource in the last run
      #
      def report
        Chef::Log.info("Creating Splunk run report")
        build_report_dir
        savetime = Time.new.utc.to_s
        save_node_data(savetime)
        save_run_data(savetime)
        save_resource_data(savetime)
        Chef::Log.info("Finished Splunk run report")
      end

      # Write out the node data
      #
      # @param [String] Takes a Time.now.to_s as an argument
      def save_node_data(savetime)
        f = Chef::Resource::File.new("#{config[:path]}/node.data", run_context)
        f.backup config[:keep].to_i
        f.mode '0644'
        node_data_content = ''
        flatten_and_expand(node).each do |k,v|
          if v.kind_of?(Array)
            v.each do |sv|
              node_data_content << "#{savetime} #{node.name} #{k}=#{sv}\n"
            end
          else
            node_data_content << "#{savetime} #{node.name} #{k}=#{v}\n"
          end
        end
        f.content(node_data_content)
        f.run_action(:create)
      end

      # Write out the run data
      #
      # @param [String] Takes a Time.now.to_s as an argument
      def save_run_data(savetime)
        f = Chef::Resource::File.new("#{config[:path]}/run.data", run_context)
        f.backup config[:keep].to_i
        f.mode '0644'
        run_data_content = ''
        run_data_content << "#{savetime} #{node.name} start_time=#{start_time}\n"
        run_data_content << "#{savetime} #{node.name} end_time=#{end_time}\n"
        run_data_content << "#{savetime} #{node.name} elapsed_time=#{elapsed_time}\n"
        run_data_content << "#{savetime} #{node.name} total_resources=#{all_resources.length}\n"
        run_data_content << "#{savetime} #{node.name} updated_resources=#{updated_resources.length}\n"
        if success?
          run_data_content << "#{savetime} #{node.name} successful=true\n"
        else
          run_data_content << "#{savetime} #{node.name} successful=false\n"
          run_data_content << "#{savetime} #{node.name} exception=#{exception}\n"
          run_data_content << "#{savetime} #{node.name} backtrace=#{backtrace}\n"
        end
        f.content(run_data_content)
        f.run_action(:create)
      end

      # Write out the resource data
      #
      # @param [String] Takes a Time.now.to_s as an argument
      def save_resource_data(savetime)
        f = Chef::Resource::File.new("#{config[:path]}/resource.data", run_context)
        f.backup config[:keep].to_i
        f.mode '0644'
        resource_data_content = ''
        all_resources.each do |r|
          resource_data_content << "#{savetime} #{node.name} type=#{r.resource_name} name=#{r.name} source_line=#{r.source_line} updated=#{r.updated?}"
          ivars = r.instance_variables.map { |ivar| ivar.to_sym } - Chef::Resource::HIDDEN_IVARS
          ivars.each do |ivar|
            if (value = r.instance_variable_get(ivar)) && !(value.respond_to?(:empty?) && value.empty?)
              resource_data_content << " #{ivar.to_s.sub(/^@/, '')}=#{value.inspect}"
            end
          end
          resource_data_content << "\n"
        end
        f.content resource_data_content
        f.run_action(:create)
      end

      # Creates the report directory, based on config[:path]
      def build_report_dir
        d = Chef::Resource::Directory.new(config[:path], run_context)
        d.mode "0755"
        d.recursive true
        d.run_action(:create)
      end

      private
      
        def flattened_item
          @flattened_item || flatten_and_expand
        end

        def flatten_and_expand(item)
          @flattened_item = Hash.new {|hash, key| hash[key] = []}

          item.each do |key, value|
            flatten_each([key.to_s], value)
          end

          @flattened_item.each_value { |values| values.uniq! }
          @flattened_item
        end

        def flatten_each(keys, values)
          case values
          when Hash
            values.each do |child_key, child_value|
              add_field_value(keys, child_key)
              flatten_each(keys + [child_key.to_s], child_value)
            end
          when Array
            values.each { |child_value| flatten_each(keys, child_value) }
          else
            add_field_value(keys, values)
          end
        end

        def add_field_value(keys, value)
          value = value.to_s
          @flattened_item[keys.join('_')] << value
          @flattened_item[keys.last] << value
        end
      
    end
  end
end
