Static and media files
======================

Let's quickly make static files work. You might not understand perfectly
what we're doing, but it will become very clear afterwards.

Setting up Django
-----------------

**First**, add these statements to
``/etc/$DJANGO_PROJECT/settings.py``::

   STATIC_ROOT = '/var/cache/$DJANGO_PROJECT/static/'
   STATIC_URL = '/static/'

Remember that after each change to your settings you need to recompile:

.. code-block:: bash

   /usr/local/$DJANGO_PROJECT-virtualenv/bin/python -m compileall \
       /etc/$DJANGO_PROJECT

**Second**, create directory ``/var/cache/$DJANGO_PROJECT/static/``:

.. code-block:: bash

   mkdir -p /var/cache/$DJANGO_PROJECT/static

The ``-p`` parameter tells ``mkdir`` to create the directory and its
parents.

**Third**, run ``collectstatic``:

.. code-block:: bash

   PYTHONPATH=/etc/$DJANGO_PROJECT:/usr/local/$DJANGO_PROJECT \
       DJANGO_SETTINGS_MODULE=settings \
       /usr/local/$DJANGO_PROJECT-virtualenv/bin/python \
       /usr/local/$DJANGO_PROJECT/manage.py collectstatic

This will copy all static files to the directory we specified in
`STATIC_ROOT`. Don't worry if you don't understand it clearly, we will
explain it in a minute.

Setting up nginx
----------------

Change ``/etc/nginx/sites-available/$DOMAIN`` to the following,
which only differs from the previous version in that the new ``location
/static {}`` block has been added at the end:

.. code-block:: nginx

    server {
        listen 80;
        listen [::]:80;
        server_name $DOMAIN www.$DOMAIN;
        root /var/www/$DOMAIN;
        location / {
            proxy_pass http://localhost:8000;
            proxy_set_header Host $http_host;
            proxy_redirect off;
            proxy_set_header X-Forwarded-For $remote_addr;
            proxy_set_header X-Forwarded-Proto $scheme;
            client_max_body_size 20m;
        }
        location /static/ {
            root /var/cache/$DJANGO_PROJECT;
        }
    }

Don't forget to execute ``service nginx reload`` after that.

Now let's try to see if it works. **Stop the Django development server**
if it is running on the server. Open your browser and visit
http://$DOMAIN/. nginx should give you a 503. This is expected, since
the backend is not working.

But now try to visit http://$DOMAIN/static/admin/img/icon_searchbox.png.
If you have ``django.contrib.admin`` in ``INSTALLED_APPS``, it should
get a search icon (if you don't use ``django.contrib.admin``, pick up
another static file that you expect to see, or browse the directory
``/var/cache/$DJANGO_PROJECT/static``).

Figure 4.1 explains how this works. Go study it now, and after everything
is clear, come back here.

The only thing that remains to clear up is what exactly these
``location`` blocks mean. ``location /static/`` means that the
configuration inside the block shall apply only if the path of the URL
(i.e. the part of the URL after stripping the protocol and host) begins
with ``/static/``. Likewise, ``location /`` applies if the path of the
URL begins with a slash. However, all paths begin with a slash, so if
the path begins with ``/static/`` both ``location`` blocks match the
URL.  Nginx only uses one ``location`` block. The rules with which nginx
chooses the ``location`` block that shall apply are complicated and are
described in the `documentation for location`_, but in this particular
case, if the path begins with ``/static/``, nginx will choose ``location
/static/``, because it is longer.

.. _documentation for location: http://nginx.org/en/docs/http/ngx_http_core_module.html#location


Setting up apache
-----------------

Change ``/etc/apache2/sites-available/$DOMAIN.conf`` to the following,
which only differs from the previous version in that new stuff has been
added at the end, starting with the ``<Location /static/>`` block:

.. code-block:: apache

   <VirtualHost *:80>
       ServerName $DOMAIN
       ServerAlias www.$DOMAIN
       DocumentRoot /var/www/$DOMAIN
       <Location />
           ProxyPass http://localhost:8000
           ProxyPreserveHost On
           RequestHeader set X-Forwarded-Proto "http"
       </Location>
       <Location /static/>
           ProxyPass !
       </Location>
       Alias /static/ /var/cache/$DJANGO_PROJECT/static/
       <Directory /var/cache/$DJANGO_PROJECT/static/>
           Options -Indexes
           Require all granted
       </Directory>
   </VirtualHost>

Don't forget to execute ``service apache2 reload`` after that.
