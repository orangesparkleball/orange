require 'orange/core'
require 'orange/resources/model_resource'
require 'orange/cartons/site_carton'
require 'dm-is-awesome_set'
module Orange
  class Route < SiteCarton
    id
    admin do
      text :slug
      text :link_text
      boolean :show_in_nav, :default => false, :display_name => 'Show in Navigation?'
    end
    orange do
      string :resource
      string :resource_id
      string :resource_action
      boolean :accept_args, :default => true
    end
    include DataMapper::Transaction::Resource # Make sure Transactions are included (for awesome_set)
    is :awesome_set, :scope => [:orange_site_id]
    
    def full_path
      self_and_ancestors.inject('') do |path, part| 
        if part.parent # Check if this is a child
          path = path + part.slug + '/' 
        else  # The root slug is just the initial '/'
          path = path + '/' 
        end
      end
    end
    
    def self.home_for_site(site_id)
      root(:orange_site_id => site_id) 
    end
    
    
    def self.create_home_for_site(site_id)
      home = self.new({:orange_site_id => site_id, :slug => '_index_', :accept_args => false, :link_text => 'Home'})
      home.move(:root)
      home.save
      home
    end
  end
  
  class SitemapResource < ModelResource
    use Orange::Route
    
    def afterLoad
      orange[:admin, true].add_link('Content', :resource => @my_orange_name, :text => 'Sitemap')
      
    end
    
    def route(packet)
      resource = packet['route.resource']
      raise 'resource not found' unless orange.loaded? resource
      unless (packet['route.resource_action'])
        packet['route.resource_action'] = (packet['route.resource_id'] ? :show : :index)
      end
      
      packet[:content] = (orange[resource].view packet)
    end
    
    def route?(packet, path)
      parts = path.split('/')
      pad = parts.shift
      matched = home(packet)
      extras = ''
      while (!parts.empty?)
        next_part = parts.shift
        matches = matched.children.first(:slug => next_part)
        if(matches) 
          matched = matches
        else
          extras = parts.unshift(next_part).unshift(pad).join('/')
          parts = []
        end
      end
      return false if(extras.length > 0 && !matched.accept_args)
      packet['route.path'] = path
      packet['route.route'] = matched
      packet['route.resource'] = matched.resource.to_sym unless matched.resource.blank?
      packet['route.resource_id'] = matched.resource_id.to_i unless matched.resource_id.blank?
      packet['route.resource_action'] = matched.resource_action.to_sym unless  matched.resource_action.blank?
      # allow "resource_paths" - extra arguments added as path parts
      packet['route.resource_path'] = extras
      return true
    end
    
    # Creates a new model object and saves it (if a post), then reroutes to the main page
    # @param [Orange::Packet] packet the packet being routed
    def new(packet, *opts)
      if packet.request.post?
        params = packet.request.params[@my_orange_name.to_s]
        params.merge!(:orange_site_id => packet['site'].id)
        a = model_class.new(params)
        a.move(:into => home(packet))
      end
      packet.reroute(@my_orange_name, :orange)
    end
    
    def higher(packet, opts = {})
      if packet.request.post?
        me = find_one(packet, :higher, packet['route.resource_id'])
        me.move(:higher) if me
      end
      packet.reroute(@my_orange_name, :orange)
    end
    
    def lower(packet, opts = {})
      if packet.request.post?
        me = find_one(packet, :lower, packet['route.resource_id'])
        me.move(:lower) if me
      end
      packet.reroute(@my_orange_name, :orange)
    end
    
    def outdent(packet, opts = {})
      if packet.request.post?
        me = find_one(packet, :outdent, packet['route.resource_id'])
        me.move(:outdent) if me
      end
      packet.reroute(@my_orange_name, :orange)
    end
    
    def indent(packet, opts = {})
      if packet.request.post?
        me = find_one(packet, :indent, packet['route.resource_id'])
        me.move(:indent) if me
      end
      packet.reroute(@my_orange_name, :orange)
    end
    
    def top_nav
      
    end
    
    def home(packet)
      site_id = packet['site'].id
      model_class.home_for_site(site_id) || model_class.create_home_for_site(site_id)
    end
    
    def routes_for(packet)
      keys = {}
      keys[:resource] = packet['route.resource'] unless packet['route.resource'].blank?
      keys[:resource_id] = packet['route.resource_id'] unless packet['route.resource_id'].blank?
      keys[:orange_site_id] = packet['site'].id unless packet['site'].blank?
      model_class.all(keys)
    end
    
    def add_link_for(packet)
      linky = ['add_route']
      linky << (packet['site'].blank? ? '0' : packet['site'].id)
      linky << (packet['route.resource'].blank? ? '0' : packet['route.resource'])
      linky << (packet['route.resource_id'].blank? ? '0' : packet['route.resource_id'])
      packet.route_to(:sitemap, linky.join('/') )
    end
    
    def add_route(packet, opts = {})
      args = packet['route.resource_path'].split('/')
      args.shift
      args = [:orange_site_id, :resource, :resource_id, :slug].inject_hash{|results, key|
        results[key] = args.shift
      }
      me = model_class.new(args)
      me.save
      me.move(:into => home(packet))
      packet.reroute(@my_orange_name, :orange,  me.id, 'edit')
      do_view(packet, :add_route, {})
    end
    
    def slug_for(model, props)
      hash = model.attributes
      return slug(model.title) if hash.has_key?(:title)
      return slug(model.name) if hash.has_key?(:name)
      return 'route-'+model.id
    end
    
    def slug(str)
      str.downcase.gsub(/[']+/, "").gsub(/[^a-z0-9]+/, "_")
    end
    
    def find_list(packet, mode, *args)
      home(packet).self_and_descendants
    end
    
    def sitemap_links(packet, opts = {})
      packet.add_js('sitemap.js', :module => '_orange_')
      opts.with_defaults!({:list => routes_for(packet) })
      opts.merge!({:add_route_link => add_link_for(packet)})
      do_list_view(packet, :sitemap_links, opts)
    end
  end
end