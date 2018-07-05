{% if page.comments %}
  <div class="comments" id="comments">
    {% if (theme.duoshuo and theme.duoshuo.shortname) or theme.duoshuo_shortname %}
      <div class="ds-thread" data-thread-key="{{ page.path }}"
           data-title="{{ page.title }}" data-url="{{ page.permalink }}">
      </div>
    {% elseif theme.facebook_sdk.enable and theme.facebook_comments_plugin.enable %}
      <div class="fb-comments"
           data-href="{{ page.permalink }}"
           data-numposts="{{ theme.facebook_comments_plugin.num_of_posts }}"
           data-width="{{ theme.facebook_comments_plugin.width }}"
           data-colorscheme="{{ theme.facebook_comments_plugin.scheme }}">
      </div>
    {% elseif theme.vkontakte_api.enable and theme.vkontakte_api.comments %}
      <div id="vk_comments"></div>
    {% elseif theme.disqus.enable %}
      <div id="disqus_thread">
        <noscript>
          Please enable JavaScript to view the
          <a href="https://disqus.com/?ref_noscript">comments powered by Disqus.</a>
        </noscript>
      </div>
    {% elseif theme.hypercomments_id %}
      <div id="hypercomments_widget"></div>
    {% elseif theme.youyan_uid %}
      <div id="uyan_frame"></div>
    {% elseif theme.livere_uid %}
      <div id="lv-container" data-id="city" data-uid="{{ theme.livere_uid }}"></div>
    {% elseif theme.changyan.appid and theme.changyan.appkey %}
      <div id="SOHUCS"></div>
    {% elseif theme.valine.appid and theme.valine.appkey %}
      <div id="vcomments"></div>
	{% elseif theme.gitment.enable %}
	  <div id="container"></div>
	  <link rel="stylesheet" href="https://imsun.github.io/gitment/style/default.css">
	  <script src="https://imsun.github.io/gitment/dist/gitment.browser.js"></script>
	  <script>
		const myTheme = {
			render(state, instance) {
			  const container = document.createElement('div');
			  container.lang = "en-US";
			  container.className = 'gitment-container gitment-root-container';
			  container.appendChild(instance.renderHeader(state, instance));
			  container.appendChild(instance.renderEditor(state, instance));
			  container.appendChild(instance.renderComments(state, instance));
			  container.appendChild(instance.renderFooter(state, instance));
			  return container;
			}
		}
		const gitment = new Gitment({
		  id: location.href,
		  theme: myTheme,
		  owner: '{{ theme.gitment.owner }}',
		  repo: '{{ theme.gitment.repo }}',
		  oauth: {
			client_id: '{{ theme.gitment.client_id }}',
			client_secret: '{{ theme.gitment.client_secret }}'
		  }
		});

		gitment.render('container');
	  
	  </script>
    {% endif %}
  </div>
{% endif %}
