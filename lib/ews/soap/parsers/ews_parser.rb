=begin
  This file is part of Viewpoint; the Ruby library for Microsoft Exchange Web Services.

  Copyright © 2011 Dan Wanek <dan.wanek@gmail.com>

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
=end

module Viewpoint::EWS::SOAP
  class EwsParser
    include Viewpoint::EWS
    include Parser

    # Parsing Methods
    # ---------------

    def resolve_names_response(opts)
      @response_message.items = resolution_set
    end

    def get_folder_response(opts)
      @response_message.items = folders
    end

    def find_folder_response(opts)
      folders = []
      q = "//#{NS_EWS_MESSAGES}:FindFolderResponseMessage//#{NS_EWS_TYPES}:Folders/*"
      @response.xpath(q, NAMESPACES).each do |f|
        folders << xml_to_hash!(f)
      end
      @response_message.items = folders
    end

    def create_folder_response(opts)
      if(@response_message.status == 'Success')
        folders = []
        q = "//#{NS_EWS_MESSAGES}:Folders/*"
        @response.xpath(q, NAMESPACES).each do |f|
          folders << xml_to_hash!(f)
        end
        @response_message.items = folders
      else
        raise EwsError, "#{@response_message.code}: #{@response_message.message}"
      end
    end

    def delete_folder_response(opts)
      if @response_message.status != 'Success'
        raise EwsError, "#{@response_message.code}: #{@response_message.message}"
      end
    end

    def get_events_response(opts)
      if @response_message.status == 'Success'
        events = []
        events << {}
        q = "//#{NS_EWS_MESSAGES}:Notification/#{NS_EWS_TYPES}:SubscriptionId"
        events.first[:subscription_id] = @response.xpath(q, NAMESPACES).first.content
        q = "//#{NS_EWS_MESSAGES}:Notification/#{NS_EWS_TYPES}:SubscriptionId"
        events.first[:more_events] = @response.xpath(q, NAMESPACES).first.content.to_boolean
        q = "//#{NS_EWS_MESSAGES}:Notification/*[position()>3]"
        @response.xpath(q, NAMESPACES).each do |e|
          events << xml_to_hash!(e)
          events.first[:watermark] = events.last[events.last.keys.first][:watermark][:text]
        end
        @response_message.items = events
      else
        raise EwsSubscriptionTimeout.new("#{@response_message.code}: #{@response_message.message}")
      end
    end

    def find_item_response(opts)
      items = []
      items << {}
      q = "//#{NS_EWS_MESSAGES}:FindItemResponseMessage/#{NS_EWS_MESSAGES}:RootFolder/@TotalItemsInView"
      items.first[:total_items_in_view] = @response.xpath(q,NAMESPACES).first.content.to_i

      q = "//#{NS_EWS_MESSAGES}:FindItemResponseMessage//#{NS_EWS_TYPES}:Items/*"
      @response.xpath(q, NAMESPACES).each do |i|
        items << xml_to_hash!(i)
      end

      @response_message.items = items
    end

    # Parsers the response from the SOAP Subscribe operation
    # @see http://msdn.microsoft.com/en-us/library/aa566188.aspx
    #
    # @return [Hash] A hash with the keys :watermark and :subscription_id
    # @raise [EwsError] Raise an error if the ResponseClass is not Success
    def subscribe_response(opts)
      subscription = []
      sid = xml_to_hash!(
        @response.xpath("//#{NS_EWS_MESSAGES}:SubscriptionId", NAMESPACES).first
      )
      wmk = xml_to_hash!(
        @response.xpath("//#{NS_EWS_MESSAGES}:Watermark", NAMESPACES).first
      )
      subscription << sid.merge(wmk)
      @response_message.items = subscription
    end

    # @todo Better handle error messages
    def unsubscribe_response(opts)
      @response_message
    end

    def get_item_response(opts)
      if(@response_message.status == 'Success')
        @response.xpath("//#{NS_EWS_MESSAGES}:Items/*", NAMESPACES).each do |item|
          @response_message.items << xml_to_hash!(item)
        end
      else
        raise EwsError, "#{@response_message.code}: #{@response_message.message}"
      end
    end

    def copy_item_response(opts)
      if(@response_message.status == 'Success')
        @response_message.items << xml_to_hash!(
          @response.xpath("//#{NS_EWS_MESSAGES}:Items/*", NAMESPACES).first
        )
      else
        raise EwsError, "#{@response_message.code}: #{@response_message.message}"
      end
    end

    def move_item_response(opts)
      if(@response_message.status == 'Success')
        @response_message.items << xml_to_hash!(
          @response.xpath("//#{NS_EWS_MESSAGES}:Items/*", NAMESPACES).first
        )
      else
        raise EwsError, "#{@response_message.code}: #{@response_message.message}"
      end
    end

    # @todo need to find out out to us XPath to get ItemId.  It doesn't seem to work now.
    def create_item_response(opts)
      if(@response_message.status == 'Success')
        items = []
        @response.xpath("//#{NS_EWS_MESSAGES}:Items/*", NAMESPACES).each do |i|
          items << xml_to_hash!(i)
        end
        @response_message.items = items
      else
        raise EwsError, "#{@response_message.code}: #{@response_message.message}"
      end
    end

    def update_item_response(opts)
      create_item_response(opts)
    end

    def send_item_response(opts)
      if(@response_message.status == 'Success')
        items = []
        @response.xpath("//#{NS_EWS_MESSAGES}:Items/*", NAMESPACES).each do |i|
          items << xml_to_hash!(i)
        end
        @response_message.items = items
      else
        raise EwsError, "#{@response_message.code}: #{@response_message.message}"
      end
    end

    def get_attachment_response(opts)
      atts = []
      if(@response_message.status == 'Success')
        q = "//#{NS_EWS_MESSAGES}:Attachments/*"
        att_id = @response.xpath(q, NAMESPACES).each do |a|
          atts << xml_to_hash!(a)
        end
        @response_message.items = atts
      else
        raise EwsError, "#{@response_message.code}: #{@response_message.message}"
      end
    end

    def create_attachment_response(opts)
      if(@response_message.status == 'Success')
        q = "//#{NS_EWS_TYPES}:FileAttachment/*"
        att_id = @response.xpath(q, NAMESPACES).last
        att_id = xml_to_hash!(att_id)
        @response_message.items = [att_id]
      else
        raise EwsError, "#{@response_message.code}: #{@response_message.message}"
      end
    end

    def sync_folder_items_response(opts)
      if(@response_message.status == 'Success')
        sync = []
        sync << {}
        q = "//#{NS_EWS_MESSAGES}:SyncState"
        sync.first[:sync_state] = @response.xpath(q,NAMESPACES).first.text
        q = "//#{NS_EWS_MESSAGES}:IncludesLastItemInRange"
        li = @response.xpath(q, NAMESPACES).first.text
        sync.first[:includes_last_item_in_range] = (li =~ /true/i ? true : false)
        @response.xpath("//m:Changes/*",NAMESPACES).each do |c|
          sync << xml_to_hash!(c)
        end
        @response_message.items = sync
      else
        raise EwsError, "#{@response_message.code}: #{@response_message.message}"
      end
    end

    def get_user_oof_settings_response(opts)
      @response_message.items = xml_to_hash!(
        @response.xpath("//#{NS_EWS_TYPES}:OofSettings", NAMESPACES).first
      )
    end

    # Parse out the free/busy time.
    # @see http://msdn.microsoft.com/en-us/library/aa494212.aspx
    def get_user_availability_response(opts)
      @response_message.items = xml_to_hash!(
        @response.xpath("//#{NS_EWS_MESSAGES}:FreeBusyView", NAMESPACES).first
      )
    end

    # Parse out a Mailbox element
    # @param [XML] mbox The <t:Mailbox> element
    # @return [Hash] Values of EWS Mailbox type :name, :email_address,
    #   :routing_type, :mailbox_type, :item_id
    def mailbox(mbox_xml)
      xml_to_hash!(mbox_xml)
    end

    def contact(contact_xml)
      xml_to_hash!(contact_xml)
    end

    # Parse out Resolutions from a ResolutionSet from the ResolveNames operation
    # @return [Array] An array of :mailbox,:contact Hashes that resolved.
    def resolution_set
      resolution_set = []
      q = "//#{NS_EWS_MESSAGES}:ResolutionSet/*"
      @response.xpath(q, NAMESPACES).each do |r|
        mbox_hash    = mailbox(r.xpath("#{NS_EWS_TYPES}:Mailbox",@namespaces).first)
        contact_xml  = r.xpath("#{NS_EWS_TYPES}:Contact",@namespaces).first
        next if !contact_xml
        resolution_set << mbox_hash.merge(contact(contact_xml))
      end
      resolution_set
    end

    def folders
      folders = []
      q = "//#{NS_EWS_MESSAGES}:Folders/*"
      @response.xpath(q, NAMESPACES).each do |f|
        folders << xml_to_hash!(f)
      end
      folders
    end

  end # EwsParser
end # Viewpoint
