<div>
  {% if not is_index %}
  <ul class="post-copyright">
    <li class="post-copyright-author">
      <strong>本文作者：</strong>{{ theme.author }}
    </li>
    <li class="post-copyright-link">
      <strong>本文链接：</strong>
        <a href="{{ url_for(page.path) }}" title="{{ page.title }}">{{ page.path }}</a>
    </li>
    <li class="post-copyright-license">
    <strong>许可协议： </strong>
      除特殊声明外，本站博文均采用 <a href="http://creativecommons.org/licenses/by-nc-sa/3.0/cn/" rel="external nofollow" target="_blank">CC BY-NC-SA 3.0 CN</a> 许可协议，转载请注明出处！
    </li>
  </ul>
  {% endif %}
</div>
