module Orange
  class BlogPostResource < Orange::ModelResource
    use Orange::Blog
    call_me :blog
    def afterLoad
      orange[:admin, true].add_link("Settings", :resource => @my_orange_name, :text => 'Blog')      
    end
    
    def blog_view(packet, opts = {})
      resource_path = packet['route.resource_path']
      if resource_path.blank?
        blog_list_view(packet, opts)
      elsif resource_path =~ /^\/page/
        blog_offset_list_view(packet, opts)
      elsif resource_path =~ /^\/archives/
        blog_archive_view(packet, opts)
      else
        blog_post_view(packet, opts)
      end
    end
    
    def blog_post_view(packet, opts = {})
      resource_path = packet['route.resource_path']
      opts.merge!( :blog_url => blog_url_for(packet))
      parts = resource_path.split('/')
      unless parts.size < 4
        post = blog.posts.year_and_month(parts[1].to_i, parts[2].to_i).slug(parts[3]) 
      end
      if post
        do_view(packet, :blog_post_view, opts.merge({:model => post}))
      else
        "Not found"
      end
    end
    
    def blog_url_for(packet)
      blog = Orange::Blog.first(:orange_site_id => packet['site'].id)      
      blog_url = orange[:sitemap, true].url_for(packet, :orange_site_id => blog.orange_site_id, :resource => :blog, :resource_id => blog.id, :resource_action => :blog_view)
      blog_url.gsub!(/\/$/, '')
    end
    
    def blog_offset_list_view(packet, opts = {})
      opts.merge!(packet.extract_opts)
      opts.merge!( :blog_url => blog_url_for(packet))
      blog = Orange::Blog.first(:orange_site_id => packet['site'].id)
      opts[:page] = opts[:page].to_i unless opts[:page].blank?
      page = opts[:page].blank? ? 0 : opts[:page] - 1 
      opts[:list] = blog.posts.published.all(:order => :published_at.desc, 
          :limit => 5, 
          :offset => (5*page)
      )
      opts[:pages] = (blog.posts.published.count / 5) + 1
      do_list_view(packet, :blog_offset_list_view, opts)
    end
    
    def blog_list_view(packet, opts = {})
      blog_offset_list_view(packet, opts.merge!({:page => 1}))
    end
    
    def blog_archive_view(packet, opts = {})
      opts.merge!( :blog_url => blog_url_for(packet))
      do_list_view(packet, :blog_archive_view, opts)
    end
    
    def find_list(packet, mode, id =false)
      blog = Orange::Blog.first(:orange_site_id => packet['site'].id)
      unless blog
        blog = Orange::Blog.new
        blog.title = 'An Orange Hosted Blog'
        blog.orange_site = packet['site']
        blog.save
        orange[:sitemap, true].add_route_for(packet,
          :orange_site_id => packet['site'].id, 
          :resource => :blog, 
          :resource_id => blog.id,
          :resource_action => :blog_view,
          :slug => 'blog', 
          :link_text => 'Orange Blog'
        )
      end
      case mode
      when :blog_list_view then blog.posts.published.all(:order => :published_at.desc, :limit => 5)
      when :blog_archive_view then blog.posts.published
      else Orange::Blog.all
      end
    end
    
  end
end